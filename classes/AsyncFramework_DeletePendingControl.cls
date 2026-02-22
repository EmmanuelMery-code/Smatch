/*** 
* @author Emmanuel (EMM) 
* @date 15/02/2026 
* @description Control class to delete pending SF_Async__c records (Executed__c=false, Cancelled__c=false).
*              When deletePending=true: deletes all pending records.
*              When deletePending=false: deletes all but stats and cleanup tasks (preserves AsyncCleanupTask, AsyncStatisticsTask).
***/ 
public with sharing class AsyncFramework_DeletePendingControl {

    /** When set, use this instead of getDeletePendingMaxIterations() for testing remaining > 0. */
    @TestVisible private static Integer testMaxIterations = null;
    /** When true, deleteOrMaintain throws to test invocable catch block. */
    @TestVisible private static Boolean testSimulateException = false;

    private static final Integer BATCH_SIZE = 200;
    private static final String CLEANUP_TASK_CLASS = AsyncCleanupTask.class.getName();
    private static final String STATISTICS_TASK_CLASS = AsyncStatisticsTask.class.getName();
    
    @InvocableMethod(
        label='Delete pending async tasks'
        description='Delete pending SF_Async__c (Executed__c=false, Cancelled__c=false). deletePending=true: delete all. deletePending=false: preserve AsyncCleanupTask and AsyncStatisticsTask. For large volumes, run multiple times.'
        category='Async Framework'
    )
    public static List<FlowResult> deletePendingControl(List<ControlRequest> requests) {
        List<FlowResult> results = new List<FlowResult>();
        for (ControlRequest req : requests) {
            FlowResult r = new FlowResult();
            try {
                DeleteResult dr = deleteOrMaintain(req.deletePending != null && req.deletePending);
                r.recordsDeleted = dr.deleted;
                r.recordsRemaining = dr.remaining;
                r.message = buildMessage(dr.deleted, dr.remaining);
            } catch (Exception e) {
                r.recordsDeleted = 0;
                r.recordsRemaining = 0;
                r.message = String.format(System.Label.Smatch_DeletePending_Error, new List<String>{ e.getMessage() });
            }
            results.add(r);
        }
        return results;
    }
    
    /*** 
    * @description Deletes pending SF_Async__c or preserves stats + cleanup according to the boolean.
    *              Capped at Delete_Pending_Max_Iterations__c from metadata (default 10). Run again if more remain.
    * @param deletePending If true: deletes all SF_Async__c with Executed__c=false and Cancelled__c=false.
    *                      If false: deletes all but stats and cleanup tasks.
    * @return DeleteResult Contains deleted count and remaining count
    ***/ 
    public static DeleteResult deleteOrMaintain(Boolean deletePending) {
        if (testSimulateException) throw new AsyncFramework_DeletePendingControlTestException('Simulated delete failure');
        String whereClause = deletePending == true
            ? 'Executed__c = false AND Cancelled__c = false'
            : 'Executed__c = false AND Cancelled__c = false AND Task_Class_Name__c != \'' + CLEANUP_TASK_CLASS + '\' AND Task_Class_Name__c != \'' + STATISTICS_TASK_CLASS + '\'';
        String soql = 'SELECT Id FROM SF_Async__c WHERE ' + whereClause + ' LIMIT ' + BATCH_SIZE;
        
        Integer totalDeleted = 0;
        Integer cpuReserve = AsyncFrameworkConfig.getCleanupCpuReserveMs();
        Boolean exitOnEmpty = false;
        
        Integer maxIterations = testMaxIterations != null ? testMaxIterations : AsyncFrameworkConfig.getDeletePendingMaxIterations();
        for (Integer iter = 0; iter < maxIterations; iter++) {
            if (Limits.getCpuTime() >= (Limits.getLimitCpuTime() - cpuReserve)) {
                break;
            }
            List<SF_Async__c> pendingRecords = Database.query(soql);
            
            if (pendingRecords.isEmpty()) {
                exitOnEmpty = true;
                break;
            }
            
            Database.DeleteResult[] results = Database.delete(pendingRecords, false);
            List<Id> successfullyDeletedIds = new List<Id>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    totalDeleted++;
                    successfullyDeletedIds.add(pendingRecords[i].Id);
                }
            }
            if (!successfullyDeletedIds.isEmpty()) {
                Database.emptyRecycleBin(successfullyDeletedIds);
            }
        }
        
        Integer remaining = 0;
        if (!exitOnEmpty && Limits.getQueries() < Limits.getLimitQueries()) {
            try {
                List<AggregateResult> arList = Database.query('SELECT COUNT(Id) cnt FROM SF_Async__c WHERE ' + whereClause);
                remaining = arList.isEmpty() ? 0 : ((Decimal)arList[0].get('cnt')).intValue();
            } catch (Exception e) {
                System.debug('AsyncFramework_DeletePendingControl: Could not count remaining. ' + e.getMessage());
            }
        }
        
        return new DeleteResult(totalDeleted, remaining);
    }
    
    private static String buildMessage(Integer deleted, Integer remaining) {
        if (remaining > 0) {
            return String.format(System.Label.Smatch_DeletePending_ResultRemaining, new List<String>{ String.valueOf(deleted), String.valueOf(remaining) });
        }
        return String.format(System.Label.Smatch_DeletePending_ResultDone, new List<String>{ String.valueOf(deleted) });
    }
    
    public class DeleteResult {
        public Integer deleted;
        public Integer remaining;
        public DeleteResult(Integer deleted, Integer remaining) {
            this.deleted = deleted;
            this.remaining = remaining;
        }
    }
    
    public class ControlRequest {
        @InvocableVariable(label='Delete all pending' description='true=delete all, false=preserve AsyncCleanupTask and AsyncStatisticsTask' required=true)
        public Boolean deletePending;
    }
    
    @TestVisible private class AsyncFramework_DeletePendingControlTestException extends Exception {}

    public class FlowResult {
        @InvocableVariable(label='Records deleted' description='Number of records deleted')
        public Integer recordsDeleted;
        @InvocableVariable(label='Records remaining' description='Number of records still pending deletion')
        public Integer recordsRemaining;
        @InvocableVariable(label='Result message' description='Result message')
        public String message;
    }
}