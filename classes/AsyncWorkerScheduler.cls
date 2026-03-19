/*** 
* @author Emmanuel (EMM) 
* @date 11/02/2026 
* @description Schedulable wrapper to enqueue AsyncWorkerQueueable. Used when the Worker
*              reschedules itself based on Scheduler_Frequency_Minutes metadata.
***/ 
public with sharing class AsyncWorkerScheduler implements Schedulable {
    
    /*** 
    * @description Aborts excess AsyncWorker scheduler jobs so only 1 remains. Ensures workers return to 1
    *              after parallel mode. Keeps the given jobId if provided (avoids going to 0 if create fails).
    *              N'abort JAMAIS le Watchdog (Async Framework Scheduler) - exclusion explicite.
    * @param keepJobId Id of the job to preserve (optional, skips aborting it)
    * @return 
    * @Exception 
    ***/ 
    private static void abortExistingWorkerSchedulerJobs(Id keepJobId) {
        try {
            List<CronTrigger> existing = [
                SELECT Id, CronJobDetail.Name FROM CronTrigger
                WHERE CronJobDetail.JobType = '7'
                AND CronJobDetail.Name LIKE 'AsyncWorker %'
                AND State != 'DELETED'
                ORDER BY CreatedDate ASC
            ];
            Integer aborted = 0;
            for (CronTrigger ct : existing) {
                if (keepJobId != null && ct.Id == keepJobId) continue;
                String name = ct.CronJobDetail != null ? ct.CronJobDetail.Name : '';
                if (String.isNotBlank(name) && (name.contains('Framework Scheduler') || name.contains('Async Framework'))) continue;
                System.abortJob(ct.Id);
                aborted++;
            }
            if (aborted > 0) {
                // System.debug('AsyncWorkerScheduler: Aborted ' + aborted + ' existing job(s) to restore single-worker mode.');
            }
        } catch (Exception e) {
            // System.debug('AsyncWorkerScheduler: Could not abort existing jobs. ' + e.getMessage());
        }
    }

    /*** 
    * @description Schedules the Worker to run in n minutes (current time + minutes).
    *              Used for initialization (Force Start, WAKEUP) so the first run is at (now + n).
    *              Crée le nouveau job AVANT d'abort pour garantir qu'au moins 1 reste en route.
    * @param minutes Number of minutes from now. If null or <= 0, uses Scheduler_Frequency_Minutes from metadata.
    * @return String The scheduled job ID
    * @Exception 
    ***/ 
    public static String scheduleInMinutes(Integer minutes) {
        if (minutes == null || minutes <= 0) {
            minutes = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
        }
        DateTime runTime = DateTime.now().addMinutes(minutes);
        String cronExp = '0 ' + runTime.minute() + ' ' + runTime.hour() + ' ' 
            + runTime.day() + ' ' + runTime.month() + ' ? ' + runTime.year();
        String jobName = 'AsyncWorker ' + runTime.format('yyyyMMddHHmmss');

        // IMPORTANT: Créer AVANT d'abort pour éviter la race (cf. logs 1206a/1206b).
        // Sinon: Worker A crée job, Worker B abort ce job puis crée le sien - si B échoue entre abort et create, 0 jobs.
        String newJobId = System.schedule(jobName, cronExp, new AsyncWorkerScheduler());
        abortExistingWorkerSchedulerJobs(String.isNotBlank(newJobId) ? Id.valueOf(newJobId) : null);
        return newJobId;
    }
    
    /*** 
    * @description Enqueues the AsyncWorkerQueueable when the scheduled job runs
    * @param sc The Schedulable context provided by Salesforce
    * @return 
    * @Exception 
    ***/ 
    public void execute(SchedulableContext sc) {
        if (sc != null) {
            abortExistingWorkerSchedulerJobs(sc.getTriggerId());
        }
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            // System.debug('AsyncWorkerScheduler: Cannot enqueue Worker, limit reached.');
            return;
        }
        System.enqueueJob(new AsyncWorkerQueueable());
    }
}