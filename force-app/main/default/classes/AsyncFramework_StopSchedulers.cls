/**
 * @description Action Flow invocable pour arrêter tous les schedulers du framework Async.
 *              Appelable depuis un Screen Flow.
 */
public with sharing class AsyncFramework_StopSchedulers {
    @TestVisible private static Boolean testSimulateAbortFailure = false;
    /** When > 0, throw only on the Nth scheduler (to test stopped + errors branches). */
    @TestVisible private static Integer testSimulateAbortFailureOnNth = 0;

    @InvocableMethod(
        label='Arrêter les Schedulers Async'
        description='Arrête tous les schedulers du framework Async (Async Framework Scheduler, AsyncScheduler).'
        category='Async Framework'
    )
    public static List<FlowResult> stopSchedulers() {
        List<FlowResult> results = new List<FlowResult>();
        FlowResult result = new FlowResult();
        List<String> stopped = new List<String>();
        List<String> errors = new List<String>();
        
        try {
            List<CronTrigger> asyncSchedulers = [
                SELECT Id, CronJobDetail.Name, State, NextFireTime
                FROM CronTrigger
                WHERE (CronJobDetail.Name LIKE '%Async%Scheduler%'
                OR CronJobDetail.Name LIKE '%Async Framework%'
                OR CronJobDetail.Name LIKE  '%AsyncWorker%') and State <> 'DELETED' 
            ];
            
            Integer ctIndex = 0;
            for (CronTrigger ct : asyncSchedulers) {
                ctIndex++;
                try {
                    Boolean shouldThrow = (Test.isRunningTest() && testSimulateAbortFailure)
                        || (Test.isRunningTest() && testSimulateAbortFailureOnNth > 0 && ctIndex == testSimulateAbortFailureOnNth);
                    if (shouldThrow) {
                        throw new AsyncFramework_StopSchedulersTestException('Simulated abort failure');
                    }
                    System.abortJob(ct.Id);
                    stopped.add(ct.CronJobDetail.Name);
                } catch (Exception e) {
                    errors.add(ct.CronJobDetail.Name + ': ' + e.getMessage());
                }
            }
            
            if (stopped.isEmpty() && errors.isEmpty()) {
                result.message = 'Aucun scheduler Async trouvé.';
            } else if (errors.isEmpty()) {
                result.message = 'Schedulers arrêtés avec succès: ' + String.join(stopped, ', ');
            } else {
                result.message = 'Arrêtés: ' + String.join(stopped, ', ') + 
                    (stopped.isEmpty() ? '' : '\n') + 
                    'Erreurs: ' + String.join(errors, '; ');
            }
        } catch (Exception e) {
            result.message = 'Erreur: ' + e.getMessage();
        }

        results.add(result);
        return results;
    }

    @TestVisible private class AsyncFramework_StopSchedulersTestException extends Exception {}

    public class FlowResult {
        @InvocableVariable(label='Résultat' description='Message de résultat')
        public String message;
    }
}