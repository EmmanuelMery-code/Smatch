/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Flow invocable action to force Worker startup and execute pending tasks.
*              Callable from a Screen Flow.
***/ 
public with sharing class AsyncFramework_ForceStart {
    @TestVisible private static Boolean testAllowEnsureWorkerRunning = false;
    @TestVisible private static Boolean simulateScheduleFailure = false;
    @TestVisible private static Boolean simulateWorkerEnqueueFailure = false;
    @TestVisible private static Boolean simulateWatchdogEnqueueFailure = false;
    @TestVisible private static Boolean simulateOuterException = false;

    /*** 
    * @description Starts the Worker and Watchdog to execute pending SF_Async__c tasks. Schedules the Scheduler if absent.
    * @param  
    * @return List<FlowResult> List containing one result with status message
    * @Exception 
    ***/ 
    @InvocableMethod(
        label='Force Start Worker'
        description='Starts the Worker and Watchdog to execute pending SF_Async__c tasks. Schedules the Scheduler if absent.'
        category='Async Framework'
    )
    public static List<FlowResult> forceStart() {
        List<FlowResult> results = new List<FlowResult>();
        FlowResult result = new FlowResult();
        List<String> messages = new List<String>();
        
        try {
            if (Test.isRunningTest() && simulateOuterException) {
                throw new AsyncFramework_ForceStartTestException('Simulated outer error');
            }
            // 1. Check pending tasks
            List<SF_Async__c> pendingTasks = [
                SELECT Id, Name, Task_Class_Name__c, Scheduled_Time__c
                FROM SF_Async__c
                WHERE Executed__c = FALSE 
                AND Cancelled__c = FALSE
                AND Scheduled_Time__c <= :System.now()
                ORDER BY Scheduled_Time__c ASC
                LIMIT 10
            ];
            
            messages.add(String.format(System.Label.Smatch_Force_PendingTasks, new List<String>{ String.valueOf(pendingTasks.size()) }));
            if (!pendingTasks.isEmpty()) {
                for (SF_Async__c task : pendingTasks) {
                    String scheduledStr = task.Scheduled_Time__c != null ? DateTimeFormatUtil.formatInUserTimezone(task.Scheduled_Time__c) : '';
                    messages.add('  - ' + task.Name + ' (' + task.Task_Class_Name__c + ')' + (String.isNotBlank(scheduledStr) ? ' - ' + scheduledStr : ''));
                }
            }
            
            Integer availableQueueable = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
            
            if (availableQueueable <= 0) {
                messages.add(System.Label.Smatch_Force_NoQueueable);
            } else {
                try {
                    if (Test.isRunningTest() && simulateWorkerEnqueueFailure) {
                        throw new AsyncFramework_ForceStartTestException('Simulated Worker failure');
                    }
                    System.enqueueJob(new AsyncWorkerQueueable());
                    messages.add(String.format(System.Label.Smatch_Force_WorkerStarted, new List<String>{ String.valueOf(AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes()) }));
                } catch (Exception e) {
                    messages.add(String.format(System.Label.Smatch_Force_WorkerError, new List<String>{ e.getMessage() }));
                }
                
                try {
                    if (Test.isRunningTest() && simulateWatchdogEnqueueFailure) {
                        throw new AsyncFramework_ForceStartTestException('Simulated Watchdog failure');
                    }
                    System.enqueueJob(new AsyncWatchdogQueueable());
                    messages.add(System.Label.Smatch_Force_WatchdogStarted);
                } catch (Exception e) {
                    messages.add(String.format(System.Label.Smatch_Force_WatchdogError, new List<String>{ e.getMessage() }));
                }
            }
            
            // Check/schedule the Scheduler
            List<CronTrigger> schedulers = [
                SELECT Id, CronJobDetail.Name, State, NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE '%AsyncScheduler%'
            ];
            
            if (schedulers.isEmpty()) {
                try {
                    if (Test.isRunningTest() && simulateScheduleFailure) {
                        throw new AsyncFramework_ForceStartTestException('Simulated for coverage');
                    }
                    String cronExpression = '0 0 * * * ?';
                    String jobId = System.schedule('Async Framework Scheduler 01', cronExpression, new AsyncScheduler());
                    messages.add(String.format(System.Label.Smatch_Force_SchedulerScheduled, new List<String>{ jobId }));
                } catch (Exception e) {
                    messages.add(String.format(System.Label.Smatch_Force_SchedulerError, new List<String>{ e.getMessage() }));
                }
            } else {
                messages.add(String.format(System.Label.Smatch_Force_SchedulerActive, new List<String>{ schedulers[0].CronJobDetail.Name, DateTimeFormatUtil.formatInUserTimezone(schedulers[0].NextFireTime) }));
            }
            
            result.message = String.join(messages, '\n');
        } catch (Exception e) {
            result.message = String.format(System.Label.Smatch_Force_Error, new List<String>{ e.getMessage() });
        }
        
        results.add(result);
        return results;
    }

    @TestVisible private class AsyncFramework_ForceStartTestException extends Exception {}

    /*** 
    * @description Enqueues only 1 Worker. Use from AsyncWorkerQueueable finally to avoid
    *              "Too many queueable jobs" (Queueable chain limit = 1 per transaction).
    *              Ne lance pas le Watchdog car on ne peut ajouter qu'un job depuis un Queueable.
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public static void ensureWorkerRunning() {
        if (Test.isRunningTest() && !testAllowEnsureWorkerRunning) return;
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) return;
        try {
            System.enqueueJob(new AsyncWorkerQueueable());
            // System.debug('AsyncFramework_ForceStart.ensureWorkerRunning: Worker enqueued.');
        } catch (Exception e) {
            // System.debug('AsyncFramework_ForceStart.ensureWorkerRunning failed: ' + e.getMessage());
        }
    }

    /*** 
    * @description Wrapper class for Flow invocable result
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class FlowResult {
        @InvocableVariable(label='Result' description='Result message')
        public String message;
    }
}