/*** 
* @author Emmanuel (EMM) 
* @date 12/02/2026 
* @description Flow invocable action to run or schedule cleanup of old SF_Async__c records.
*              START = immediate execution with default config (Days_To_Keep, Cleanup_Batch_Size, etc.).
*              START_DAILY = schedule cleanup as daily SMATCH task.
*              STOP = cancel pending daily cleanup tasks.
***/ 
public with sharing class AsyncFramework_CleanupControl {
    
    private static final String CLEANUP_TASK_CLASS = AsyncCleanupTask.class.getName();
    
    @InvocableMethod(
        label='Control data cleanup'
        description='START=immediate cleanup. START_DAILY=schedule daily cleanup via SMATCH. STOP=cancel scheduled cleanup.'
        category='Async Framework'
    )
    public static List<FlowResult> controlCleanup(List<ControlRequest> requests) {
        List<FlowResult> results = new List<FlowResult>();
        
        for (ControlRequest request : requests) {
            FlowResult result = new FlowResult();
            try {
                if (request.action == 'START') {
                    SF_Async__c contextRecord = new SF_Async__c(
                        label__c = 'Cleanup (on demand)',
                        Task_Class_Name__c = CLEANUP_TASK_CLASS,
                        Scheduled_Time__c = System.now(),
                        Before_Cancelling__c = AsyncFrameworkConfig.getBeforeCancelling(),
                        Execution_Order__c = AsyncFrameworkConfig.getExecutionOrder()
                    );
                    insert contextRecord;
                    new AsyncCleanupTask().run(contextRecord);
                    contextRecord.Executed__c = true;
                    update contextRecord;
                    result.message = 'Cleanup executed successfully. Uses default config: Days_To_Keep=' + AsyncFrameworkConfig.getDaysToKeep() + ', Batch_Size=' + AsyncFrameworkConfig.getCleanupBatchSize() + '.';
                } else if (request.action == 'START_DAILY') {
                    List<SF_Async__c> existing = [
                        SELECT Id FROM SF_Async__c
                        WHERE Task_Class_Name__c = :CLEANUP_TASK_CLASS
                        AND Executed__c = FALSE
                        AND Cancelled__c = FALSE
                    ];
                    if (!existing.isEmpty()) {
                        result.message = 'Daily cleanup already scheduled. ' + existing.size() + ' task(s) pending.';
                    } else {
                        SF_Async__c task = new SF_Async__c(
                            label__c = 'Daily Cleanup',
                            Task_Class_Name__c = CLEANUP_TASK_CLASS,
                            Scheduled_Time__c = System.now(),
                            Before_Cancelling__c = AsyncFrameworkConfig.getBeforeCancelling(),
                            Execution_Order__c = AsyncFrameworkConfig.getExecutionOrder()
                        );
                        insert task;
                        result.message = 'Daily cleanup scheduled. Will run now then automatically once per day.';
                    }
                } else if (request.action == 'STOP') {
                    List<SF_Async__c> pendingTasks = [
                        SELECT Id, label__c, Before_Cancelling__c
                        FROM SF_Async__c
                        WHERE Task_Class_Name__c = :CLEANUP_TASK_CLASS
                        AND Executed__c = FALSE
                        AND Cancelled__c = FALSE
                    ];
                    if (!pendingTasks.isEmpty()) {
                        for (SF_Async__c t : pendingTasks) {
                            t.Tries__c = (t.Before_Cancelling__c != null && t.Before_Cancelling__c > 0)
                                ? Integer.valueOf(t.Before_Cancelling__c) : 1;
                        }
                        update pendingTasks;
                        result.message = 'Daily cleanup cancelled. ' + pendingTasks.size() + ' task(s) stopped.';
                    } else {
                        result.message = 'No scheduled cleanup task in progress.';
                    }
                } else {
                    result.message = 'Unknown action. Use START, START_DAILY or STOP.';
                }
            } catch (Exception e) {
                result.message = 'Error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
    
    public class ControlRequest {
        @InvocableVariable(label='Action' description='START (immediate), START_DAILY (daily SMATCH), STOP (cancel scheduled)' required=true)
        public String action;
    }
    
    public class FlowResult {
        @InvocableVariable(label='Result' description='Result message')
        public String message;
    }
}