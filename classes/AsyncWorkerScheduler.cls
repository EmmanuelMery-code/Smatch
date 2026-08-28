/*** 
* @author Emmanuel (EMM) 
* @date 11/02/2026 
* @description Schedulable wrapper to enqueue AsyncWorkerQueueable. Used when the Worker
*              reschedules itself based on Scheduler_Frequency_Minutes metadata.
*              Idempotence par recherche d'un job vivant, jamais par nom fixe : le cron produit
*              ici est un one-shot, et reutiliser son nom apres declenchement fait echouer
*              System.schedule. Aucun abortJob n'est effectue (deadlock cReferences).
***/ 
public with sharing class AsyncWorkerScheduler implements Schedulable {

    @TestVisible private static final String JOB_NAME_PREFIX = AsyncCronJobNames.WORKER_PREFIX;

    /*** 
    * @description Returns the Id of an already scheduled AsyncWorker job, if any.
    *              Couvre le nom canonique et les noms horodates des versions precedentes.
    ***/ 
    private static Id findExistingWorkerJobId() {
        return AsyncCronJobNames.findLiveJobId(JOB_NAME_PREFIX);
    }

    /*** 
    * @description Schedules the Worker to run in n minutes (current time + minutes).
    *              Idempotent : si un job vivant existe deja, son Id est renvoye sans replanifier.
    *              Sinon un nom unique est genere, pour que le CronJobDetail du precedent one-shot
    *              ne bloque pas la creation. Never aborts jobs (deadlock).
    * @param minutes Number of minutes from now. If null or <= 0, uses Scheduler_Frequency_Minutes from metadata.
    * @return String The scheduled job ID, or null when no Worker run could be scheduled
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
            return System.schedule(AsyncCronJobNames.uniqueName(JOB_NAME_PREFIX), cronExp, new AsyncWorkerScheduler());
        } catch (Exception e) {
            // Une course a pu creer le job entre-temps ; sinon on renvoie null pour que
            // l'appelant sache qu'aucune relance n'est garantie, au lieu de le masquer.
            existingId = findExistingWorkerJobId();
            return existingId != null ? String.valueOf(existingId) : null;
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