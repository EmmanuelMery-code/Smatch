/*** 
* @author Emmanuel (EMM) 
* @date 11/02/2026 
* @description Schedulable wrapper to enqueue AsyncWorkerQueueable. Used when the Worker
*              reschedules itself based on Scheduler_Frequency_Minutes metadata.
*              Uses a single fixed job name so concurrent workers never System.schedule+abortJob
*              the same Apex class (uncatchable deadlock on cReferences.insert_references).
***/ 
public with sharing class AsyncWorkerScheduler implements Schedulable {

    @TestVisible private static final String JOB_NAME = 'AsyncWorker Recurring';

    /*** 
    * @description Returns the Id of an already scheduled AsyncWorker job, if any.
    *              Includes the canonical name and leftover timestamped names from older versions.
    ***/ 
    private static Id findExistingWorkerJobId() {
        List<CronTrigger> existing = [
            SELECT Id, CronJobDetail.Name FROM CronTrigger
            WHERE CronJobDetail.JobType = '7'
            AND CronJobDetail.Name LIKE 'AsyncWorker%'
            AND State != 'DELETED'
            ORDER BY CreatedDate ASC
        ];
        for (CronTrigger ct : existing) {
            String name = ct.CronJobDetail != null ? ct.CronJobDetail.Name : '';
            if (name == JOB_NAME) {
                return ct.Id;
            }
        }
        return existing.isEmpty() ? null : existing[0].Id;
    }

    /*** 
    * @description Schedules the Worker to run in n minutes (current time + minutes).
    *              Idempotent: a single fixed job name is used. If it already exists, System.schedule
    *              is not retried after a duplicate error. Never aborts jobs (deadlock).
    * @param minutes Number of minutes from now. If null or <= 0, uses Scheduler_Frequency_Minutes from metadata.
    * @return String The scheduled job ID, or a non-blank marker when the job already exists
    ***/ 
    public static String scheduleInMinutes(Integer minutes) {
        if (minutes == null || minutes <= 0) {
            minutes = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
        }
        Id existingId = findExistingWorkerJobId();
        if (existingId != null) {
            return String.valueOf(existingId);
        }
        DateTime runTime = DateTime.now().addMinutes(minutes);
        String cronExp = '0 ' + runTime.minute() + ' ' + runTime.hour() + ' '
            + runTime.day() + ' ' + runTime.month() + ' ? ' + runTime.year();
        try {
            return System.schedule(JOB_NAME, cronExp, new AsyncWorkerScheduler());
        } catch (Exception e) {
            existingId = findExistingWorkerJobId();
            return existingId != null ? String.valueOf(existingId) : JOB_NAME;
        }
    }
    
    /*** 
    * @description Enqueues the AsyncWorkerQueueable when the scheduled job runs
    * @param sc The Schedulable context provided by Salesforce
    ***/ 
    public void execute(SchedulableContext sc) {
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            return;
        }
        System.enqueueJob(new AsyncWorkerQueueable());
    }
}