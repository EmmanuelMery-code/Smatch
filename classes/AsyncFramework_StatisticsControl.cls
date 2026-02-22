/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Flow invocable action to start or stop statistics calculation (AsyncLearningBatch).
*              START = immediate batch execution.
*              START_DAILY = register as SMATCH task executed daily by the framework.
*              STOP = stop running batch and cancel scheduled daily calculation.
***/ 
public with sharing class AsyncFramework_StatisticsControl {
    
    private static final String STATISTICS_TASK_CLASS = AsyncStatisticsTask.class.getName();
    
    /*** 
    * @description Processes control requests: START (immediate batch), START_DAILY (daily SMATCH task), STOP (stop all).
    * @param requests List of control requests with action parameter
    * @return List<FlowResult> List of results, one per request
    * @Exception 
    ***/ 
    @InvocableMethod(
        label='Control statistics calculation'
        description='START=immediate execution. START_DAILY=daily scheduling via SMATCH. STOP=stop all.'
        category='Async Framework'
    )
    public static List<FlowResult> controlStatistics(List<ControlRequest> requests) {
        List<FlowResult> results = new List<FlowResult>();
        
        for (ControlRequest request : requests) {
            FlowResult result = new FlowResult();
            try {
                if (request.action == 'START') {
                    Id jobId = Database.executeBatch(new AsyncLearningBatch());
                    result.message = String.format(System.Label.Smatch_Stats_Started, new List<String>{ String.valueOf(jobId) });
                } else if (request.action == 'START_DAILY') {
                    // Check that no daily task is already scheduled
                    List<SF_Async__c> existing = [
                        SELECT Id FROM SF_Async__c
                        WHERE Task_Class_Name__c = :STATISTICS_TASK_CLASS
                        AND Executed__c = FALSE
                        AND Cancelled__c = FALSE
                    ];
                    if (!existing.isEmpty()) {
                        result.message = String.format(System.Label.Smatch_Stats_DailyAlreadyScheduled, new List<String>{ String.valueOf(existing.size()) });
                    } else {
                        SF_Async__c task = new SF_Async__c(
                            label__c = System.Label.Smatch_Stats_Label_DailyTask,
                            Task_Class_Name__c = STATISTICS_TASK_CLASS,
                            Scheduled_Time__c = System.now(),
                            Before_Cancelling__c = AsyncFrameworkConfig.getBeforeCancelling(),
                            Execution_Order__c = AsyncFrameworkConfig.getExecutionOrder()
                        );
                        insert task;
                        result.message = System.Label.Smatch_Stats_Inscribed;
                    }
                } else if (request.action == 'STOP') {
                    List<String> messages = new List<String>();
                    
                    // 1. Stop running AsyncLearningBatch batches
                    List<AsyncApexJob> runningBatch = [
                        SELECT Id, Status
                        FROM AsyncApexJob
                        WHERE ApexClass.Name = 'AsyncLearningBatch'
                        AND Status IN ('Queued', 'Processing', 'Preparing', 'Holding')
                    ];
                    for (AsyncApexJob job : runningBatch) {
                        try {
                            System.abortJob(job.Id);
                            messages.add(String.format(System.Label.Smatch_Stats_BatchStopped, new List<String>{ String.valueOf(job.Id) }));
                        } catch (Exception e) {
                            messages.add(String.format(System.Label.Smatch_Stats_BatchError, new List<String>{ String.valueOf(job.Id), e.getMessage() }));
                        }
                    }
                    
                    // 2. Cancel pending SMATCH AsyncStatisticsTask tasks (daily calculation)
                    // Cancelled__c is a formula = Tries__c >= Before_Cancelling__c, set Tries to max value
                    List<SF_Async__c> pendingTasks = [
                        SELECT Id, label__c, Before_Cancelling__c
                        FROM SF_Async__c
                        WHERE Task_Class_Name__c = :STATISTICS_TASK_CLASS
                        AND Executed__c = FALSE
                        AND Cancelled__c = FALSE
                    ];
                    if (!pendingTasks.isEmpty()) {
                        for (SF_Async__c t : pendingTasks) {
                            t.Tries__c = (t.Before_Cancelling__c != null && t.Before_Cancelling__c > 0)
                                ? Integer.valueOf(t.Before_Cancelling__c) : 1;
                        }
                        update pendingTasks;
                        messages.add(String.format(System.Label.Smatch_Stats_DailyStopped, new List<String>{ String.valueOf(pendingTasks.size()) }));
                    }
                    
                    if (messages.isEmpty()) {
                        result.message = System.Label.Smatch_Stats_NothingInProgress;
                    } else {
                        result.message = String.join(messages, '\n');
                    }
                } else {
                    result.message = System.Label.Smatch_Stats_ActionUnknown;
                }
            } catch (Exception e) {
                result.message = String.format(System.Label.Smatch_Stats_Error, new List<String>{ e.getMessage() });
            }
            results.add(result);
        }
        return results;
    }
    
    /*** 
    * @description Wrapper class for Flow invocable control request input
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class ControlRequest {
        @InvocableVariable(label='Action' description='START (immediate), START_DAILY (daily SMATCH), STOP (stop all)' required=true)
        public String action;
    }
    
    /*** 
    * @description Wrapper class for Flow invocable control result
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class FlowResult {
        @InvocableVariable(label='Result' description='Result message')
        public String message;
    }
}