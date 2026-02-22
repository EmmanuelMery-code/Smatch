/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Automatic cleanup task that deletes old SF_Async__c records (more than 30 days old)
*              and executed or cancelled. Automatically reschedules its execution for the next day.
***/ 
public with sharing class AsyncCleanupTask implements IAsyncTask {
    
    // Configuration constants are now retrieved from Custom Metadata via AsyncFrameworkConfig
    // This allows configuration changes without code deployment and does not consume SOQL queries
    
    /*** 
    * @description Executes cleanup of old records and reschedules the next execution
    * @param contextRecord The SF_Async__c context record (not used in this implementation)
    * @return 
    * @Exception 
    ***/ 
    public void run(SF_Async__c contextRecord) {
        try {
            Date limitDate = System.today().addDays(-AsyncFrameworkConfig.getDaysToKeep());
            Integer batchSize = AsyncFrameworkConfig.getCleanupBatchSize();
            Integer cpuReserve = AsyncFrameworkConfig.getCleanupCpuReserveMs();
            
            // Single SOQL outside any loop - avoids governor limit (100 SOQL/transaction)
            // Process one batch per execution; next run (scheduled daily) will process more
            List<SF_Async__c> oldRecords = [
                SELECT Id 
                FROM SF_Async__c 
                WHERE CreatedDate < :limitDate 
                AND (Executed__c = TRUE OR Cancelled__c = TRUE) 
                LIMIT :batchSize
            ];
            
            if (!oldRecords.isEmpty() && Limits.getCpuTime() < (Limits.getLimitCpuTime() - cpuReserve)) {
                List<Id> deletedIds = new List<Id>();
                Database.DeleteResult[] deleteResults = Database.delete(oldRecords, false);
                for (Integer i = 0; i < deleteResults.size(); i++) {
                    if (deleteResults[i].isSuccess()) {
                        deletedIds.add(oldRecords[i].Id);
                    }
                }
                if (!deletedIds.isEmpty()) {
                    Database.emptyRecycleBin(deletedIds);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error during cleanup: ' + e.getMessage());
        } finally {
            // Rescheduling guaranteed even in case of error
            scheduleNextRunIfNeeded();
        }
    }
    
    /*** 
    * @description Checks and creates the next cleanup task if necessary to avoid duplicates
    * @param  
    * @return 
    * @Exception 
    ***/ 
    private void scheduleNextRunIfNeeded() {
        // Idempotency check: avoids duplicates if multiple instances run simultaneously
        String className = AsyncCleanupTask.class.getName();
        Date tomorrow = System.today().addDays(1);
        
        Integer existingJobs = [
            SELECT Count() 
            FROM SF_Async__c 
            WHERE Task_Class_Name__c = :className 
            AND Scheduled_Time__c >= :tomorrow
            AND Executed__c = FALSE
            AND Cancelled__c = FALSE
            LIMIT 1
        ];
        
        if (existingJobs == 0) {
            SF_Async__c nextRun = new SF_Async__c(
                label__c = 'Daily Cleanup',
                Task_Class_Name__c = className,
                Scheduled_Time__c = System.now().addDays(1),
                Before_Cancelling__c = AsyncFrameworkConfig.getBeforeCancelling(),
                Execution_Order__c = AsyncFrameworkConfig.getExecutionOrder()
            );
            insert nextRun;
        } else {
            System.debug('Cleanup already scheduled for tomorrow. No duplicate created.');
        }
    }
}