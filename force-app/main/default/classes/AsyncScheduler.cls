/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Schedulable scheduler that launches the Watchdog Queueable to monitor worker state.
*              Handles queued job limits and Flex Queue full errors.
***/ 
public with sharing class AsyncScheduler implements Schedulable {
    @TestVisible private static Boolean simulateEnqueueFailure = false;

    /*** 
    * @description Executes the scheduler by launching the Watchdog Queueable if limits allow
    * @param SC The Schedulable context provided by Salesforce
    * @return 
    * @Exception 
    ***/ 
    public void execute(SchedulableContext SC) {
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            // System.debug('AsyncScheduler: Cannot launch Watchdog, limit reached for this transaction.');
            return;
        }

        try {
            if (Test.isRunningTest() && simulateEnqueueFailure) {
                throw new AsyncSchedulerTestException('Simulated for coverage');
            }
            System.enqueueJob(new AsyncWatchdogQueueable());
        } catch (Exception e) {
            // Error handling (Flex Queue full, limits reached, etc.)
            // The Watchdog will be relaunched at the next scheduled execution
            String errorType = e.getTypeName();
            if (errorType.contains('FlexQueue') || errorType.contains('LimitException')) {
                // System.debug('AsyncScheduler: Flex Queue is full or limit reached. Watchdog will retry later. Error: ' + e.getMessage());
            } else {
                // System.debug('AsyncScheduler: Unexpected error: ' + e.getMessage());
            }
        }
    }

    @TestVisible private class AsyncSchedulerTestException extends Exception {}
}