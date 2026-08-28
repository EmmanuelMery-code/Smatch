/*** 
* @author Emmanuel (EMM) 
* @date 28/08/2026 
* @description Centralise le nommage et la recherche des jobs cron du framework Async.
*              Les jobs du framework sont des crons "one-shot" replanifies a chaque execution.
*              Un nom fixe ne peut donc pas etre reutilise : le CronJobDetail du job precedent
*              survit a son declenchement (CronTrigger a l'etat DELETED) et fait echouer
*              System.schedule, ce qui arrete definitivement la chaine de replanification.
***/ 
public with sharing class AsyncCronJobNames {

    /** Prefixe des jobs qui enfilent le Worker (AsyncWorkerScheduler). */
    public static final String WORKER_PREFIX = 'AsyncWorker';

    /** Prefixe des jobs qui enfilent le Watchdog (AsyncScheduler / AsyncSchedulerSelfRescheduling). */
    public static final String WATCHDOG_PREFIX = 'Async Framework Scheduler';

    /** Discriminant intra-transaction : l'horodatage seul ne suffit pas dans une boucle de planification. */
    private static Integer sequence = 0;

    /*** 
    * @description Derive un nom de job unique a partir d'un prefixe, horodate a la milliseconde.
    *              Le prefixe reste interrogeable en LIKE '<prefixe>%'.
    * @param prefix Prefixe du job (voir WORKER_PREFIX / WATCHDOG_PREFIX)
    * @return String Nom de job unique
    ***/ 
    public static String uniqueName(String prefix) {
        String base = String.isBlank(prefix) ? 'AsyncJob' : prefix;
        sequence++;
        return base + ' ' + DateTime.now().formatGmt('yyyyMMddHHmmssSSS') + '-' + sequence;
    }

    /*** 
    * @description Id d'un job cron encore capable de se declencher pour ce prefixe, ou null.
    *              Exclut le seul etat DELETED : un one-shot deja declenche ne relancera plus rien,
    *              et le considerer comme present est ce qui a fige le framework. A l'inverse,
    *              ACQUIRED et EXECUTING comptent comme presents (leur NextFireTime est nul le
    *              temps du declenchement) : les ignorer ferait creer un doublon a chaque cycle.
    * @param prefix Prefixe du job recherche
    * @return Id Id du CronTrigger vivant le plus proche, ou null
    ***/ 
    public static Id findLiveJobId(String prefix) {
        if (String.isBlank(prefix)) {
            return null;
        }
        String pattern = prefix + '%';
        List<CronTrigger> liveJobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.JobType = '7'
            AND CronJobDetail.Name LIKE :pattern
            AND State != 'DELETED'
            ORDER BY NextFireTime ASC NULLS LAST
            LIMIT 1
        ];
        return liveJobs.isEmpty() ? null : liveJobs[0].Id;
    }
}
