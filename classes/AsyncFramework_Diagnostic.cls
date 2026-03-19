/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Flow invocable action to diagnose the Async framework state.
*              Callable from a Screen Flow.
***/ 
public with sharing class AsyncFramework_Diagnostic {

    @TestVisible private static Boolean testSimulateException = false;

    /*** 
    * @description Displays the state of tasks, workers, schedulers and error logs of the Async framework.
    * @param  
    * @return List<FlowResult> List containing one result with diagnostic message
    * @Exception 
    ***/ 
    @InvocableMethod(
        label='Diagnostic Async Framework'
        description='Displays the state of tasks, workers, schedulers and error logs of the Async framework.'
        category='Async Framework'
    )
    public static List<FlowResult> runDiagnostic() {
        List<FlowResult> results = new List<FlowResult>();
        FlowResult result = new FlowResult();
        List<String> lines = new List<String>();
        
        try {
            if (testSimulateException) throw new AsyncFramework_DiagnosticTestException('Simulated diagnostic failure');
            lines.add(System.Label.Smatch_Diag_Header);
            lines.add(String.format(System.Label.Smatch_Diag_DateTime, new List<String>{ DateTimeFormatUtil.formatNowInUserTimezone() }));
            lines.add('');
            
            // 1. Pending tasks
            List<SF_Async__c> pendingTasks = [
                SELECT Id, Name, Task_Class_Name__c, Scheduled_Time__c
                FROM SF_Async__c
                WHERE Executed__c = FALSE 
                AND Cancelled__c = FALSE
                AND Scheduled_Time__c <= :System.now()
                ORDER BY Scheduled_Time__c ASC
                LIMIT 10
            ];
            
            lines.add(String.format(System.Label.Smatch_Diag_PendingTasks, new List<String>{ String.valueOf(pendingTasks.size()) }));
            for (SF_Async__c task : pendingTasks) {
                String scheduledStr = task.Scheduled_Time__c != null ? DateTimeFormatUtil.formatInUserTimezone(task.Scheduled_Time__c) : '';
                lines.add('  - ' + task.Name + ' (' + task.Task_Class_Name__c + ') - ' + scheduledStr);
            }
            lines.add('');
            
            // 2. Recent tasks (all types)
            List<SF_Async__c> recentTasks = [
                SELECT Id, Name, label__c, Task_Class_Name__c, Scheduled_Time__c, Executed__c, Cancelled__c, Tries__c
                FROM SF_Async__c
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            
            lines.add(System.Label.Smatch_Diag_RecentTasks);
            for (SF_Async__c task : recentTasks) {
                lines.add('  - ' + task.label__c + ' | ' + task.Task_Class_Name__c + ' | Executed: ' + task.Executed__c + ' | Cancelled: ' + task.Cancelled__c);
            }
            lines.add('');
            
            // 3. Error logs
            List<SF_Async_Log__c> errorLogs = [
                SELECT Id, Message__c, CreatedDate
                FROM SF_Async_Log__c
                WHERE Status__c = 'Error'
                AND CreatedDate >= :System.now().addHours(-2)
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            
            lines.add(String.format(System.Label.Smatch_Diag_Errors, new List<String>{ String.valueOf(errorLogs.size()) }));
            for (SF_Async_Log__c log : errorLogs) {
                String msg = log.Message__c != null && log.Message__c.length() > 100 
                    ? log.Message__c.substring(0, 100) + '...' : log.Message__c;
                String createdStr = log.CreatedDate != null ? DateTimeFormatUtil.formatInUserTimezone(log.CreatedDate) : '';
                lines.add('  - ' + createdStr + ': ' + msg);
            }
            lines.add('');
            
            // 4. Recent workers
            List<AsyncApexJob> workers = [
                SELECT Id, Status, CreatedDate
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'AsyncWorkerQueueable'
                AND CreatedDate >= :System.now().addHours(-2)
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            
            lines.add(String.format(System.Label.Smatch_Diag_Workers, new List<String>{ String.valueOf(workers.size()) }));
            for (AsyncApexJob job : workers) {
                String createdStr = job.CreatedDate != null ? DateTimeFormatUtil.formatInUserTimezone(job.CreatedDate) : '';
                lines.add('  - ' + job.Status + ' (' + createdStr + ')');
            }
            lines.add('');
            
            // 5. Schedulers (most recent first)
            List<CronTrigger> schedulers = [
                SELECT Id, CronJobDetail.Name, State, NextFireTime, CreatedDate
                FROM CronTrigger
                WHERE (CronJobDetail.Name LIKE '%Async%Scheduler%' OR CronJobDetail.Name LIKE '%AsyncWorker%')
                AND State <> 'DELETED'
                ORDER BY CreatedDate DESC
            ];
            
            lines.add(String.format(System.Label.Smatch_Diag_Schedulers, new List<String>{ String.valueOf(schedulers.size()) }));
            for (CronTrigger ct : schedulers) {
                String nextStr = ct.NextFireTime != null ? DateTimeFormatUtil.formatInUserTimezone(ct.NextFireTime) : '';
                lines.add('  - ' + ct.CronJobDetail.Name + ' | State: ' + ct.State + ' | Next: ' + nextStr);
            }
            lines.add('');
            
            // 6. Statistics scheduled (AsyncStatisticsTask)
            List<SF_Async__c> statsTasks = [
                SELECT Id, label__c, Scheduled_Time__c
                FROM SF_Async__c
                WHERE Task_Class_Name__c = 'AsyncStatisticsTask'
                AND Executed__c = FALSE
                AND Cancelled__c = FALSE
                AND Scheduled_Time__c >= :System.now()
                ORDER BY Scheduled_Time__c ASC
                LIMIT 1
            ];
            if (!statsTasks.isEmpty()) {
                lines.add('STATISTICS SCHEDULED: Yes');
                lines.add('  Frequency: Daily | Next calculation: ' + DateTimeFormatUtil.formatInUserTimezone(statsTasks[0].Scheduled_Time__c));
            } else {
                lines.add('STATISTICS SCHEDULED: No');
            }
            lines.add('');
            
            // 7. Cleanup scheduled (AsyncCleanupTask)
            List<SF_Async__c> cleanupTasks = [
                SELECT Id, label__c, Scheduled_Time__c
                FROM SF_Async__c
                WHERE Task_Class_Name__c = 'AsyncCleanupTask'
                AND Executed__c = FALSE
                AND Cancelled__c = FALSE
                AND Scheduled_Time__c >= :System.now()
                ORDER BY Scheduled_Time__c ASC
                LIMIT 1
            ];
            if (!cleanupTasks.isEmpty()) {
                lines.add('CLEANUP SCHEDULED: Yes');
                lines.add('  Frequency: Daily | Next execution: ' + DateTimeFormatUtil.formatInUserTimezone(cleanupTasks[0].Scheduled_Time__c));
            } else {
                lines.add('CLEANUP SCHEDULED: No');
            }
            lines.add('');
            
            // 8. Watchdog scheduled (AsyncScheduler / AsyncSchedulerSelfRescheduling)
            List<CronTrigger> allSchedulerJobs = [
                SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State
                FROM CronTrigger
                WHERE CronJobDetail.JobType = '7'
                AND (CronJobDetail.Name LIKE '%Async Framework Scheduler%' OR CronJobDetail.Name LIKE '%Async%Scheduler%')
                ORDER BY NextFireTime ASC
                LIMIT 10
            ];
            List<CronTrigger> watchdogJobs = new List<CronTrigger>();
            for (CronTrigger ct : allSchedulerJobs) {
                if (ct.State != 'DELETED' && ct.CronJobDetail.Name != null
                    && !ct.CronJobDetail.Name.startsWith('AsyncWorker')) {
                    watchdogJobs.add(ct);
                    if (watchdogJobs.size() >= 5) break;
                }
            }
            if (!watchdogJobs.isEmpty()) {
                lines.add('WATCHDOG SCHEDULED: Yes');
                Integer freqMin = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
                for (CronTrigger ct : watchdogJobs) {
                    String nextStr = ct.NextFireTime != null ? DateTimeFormatUtil.formatInUserTimezone(ct.NextFireTime) : '';
                    lines.add('  Name: ' + ct.CronJobDetail.Name + ' | Frequency: ' + freqMin + ' min | Next: ' + nextStr);
                }
            } else {
                lines.add('WATCHDOG SCHEDULED: No');
            }
            lines.add('');
            
            // 9. Worker scheduled (AsyncWorkerScheduler)
            List<CronTrigger> workerJobs = [
                SELECT Id, CronJobDetail.Name, NextFireTime
                FROM CronTrigger
                WHERE CronJobDetail.JobType = '7'
                AND CronJobDetail.Name LIKE 'AsyncWorker%'
                AND State <> 'DELETED'
                AND NextFireTime >= :System.now()
                ORDER BY NextFireTime ASC
                LIMIT 5
            ];
            if (!workerJobs.isEmpty()) {
                lines.add('WORKER SCHEDULED: Yes');
                Integer workerFreq = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
                for (CronTrigger ct : workerJobs) {
                    String nextStr = ct.NextFireTime != null ? DateTimeFormatUtil.formatInUserTimezone(ct.NextFireTime) : '';
                    lines.add('  Name: ' + ct.CronJobDetail.Name + ' | Frequency: ' + workerFreq + ' min | Next: ' + nextStr);
                }
            } else {
                lines.add('WORKER SCHEDULED: No');
            }
            
            lines.add('');
            lines.add(System.Label.Smatch_Diag_Footer);
            result.message = String.join(lines, '\n');
            
        } catch (Exception e) {
            result.message = String.format(System.Label.Smatch_Diag_Error, new List<String>{ e.getMessage() }) + '\n' + e.getStackTraceString();
        }
        
        results.add(result);
        return results;
    }
    
    /*** 
    * @description Wrapper class for Flow invocable diagnostic result
    * @param  
    * @return 
    * @Exception 
    ***/ 
    @TestVisible private class AsyncFramework_DiagnosticTestException extends Exception {}

    public class FlowResult {
        @InvocableVariable(label='Result' description='Diagnostic result')
        public String message;
    }
}