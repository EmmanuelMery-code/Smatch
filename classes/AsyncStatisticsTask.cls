/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description SMATCH task that runs statistics calculation (AsyncLearningBatch)
*              and reschedules itself automatically once per day.
***/ 
public with sharing class AsyncStatisticsTask implements IAsyncTask {
    
    /*** 
    * @description Executes the statistics calculation batch and schedules the next run for the next day.
    * @param contextRecord The SF_Async__c context record (not used in this implementation)
    * @return 
    * @Exception 
    ***/ 
    public void run(SF_Async__c contextRecord) {
        try {
            Database.executeBatch(new AsyncLearningBatch());
        } catch (Exception e) {
            // System.debug('AsyncStatisticsTask: Error launching batch - ' + e.getMessage());
        } finally {
            scheduleNextRunIfNeeded();
        }
    }
    
    /*** 
    * @description Checks and creates the next statistics task if necessary to avoid duplicates
    * @param  
    * @return 
    * @Exception 
    ***/ 
    private void scheduleNextRunIfNeeded() {
        String className = AsyncStatisticsTask.class.getName();
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
                label__c = System.Label.Smatch_Stats_Label_DailyTask,
                Task_Class_Name__c = className,
                Scheduled_Time__c = System.now().addDays(1),
                Before_Cancelling__c = AsyncFrameworkConfig.getBeforeCancelling(),
                Execution_Order__c = AsyncFrameworkConfig.getExecutionOrder()
            );
            insert nextRun;
        }
    }
}