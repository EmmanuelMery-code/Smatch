/*** 
* @author Emmanuel (EMM) 
* @date 12/02/2026 
* @description Schedulable that launches the Watchdog and reschedules itself N minutes later.
*              Used when user chooses "single scheduler" mode (1 job instead of N cron jobs).
***/ 
public with sharing class AsyncSchedulerSelfRescheduling implements Schedulable {
    @TestVisible private static Boolean simulateEnqueueFailure = false;
    @TestVisible private static Boolean simulateRescheduleFailure = false;

    private static final String JOB_NAME = 'Async Framework Scheduler 01';

    /*** 
    * @description Executes the scheduler by launching the Watchdog Queueable and rescheduling itself
    * @param SC The Schedulable context provided by Salesforce
    * @return 
    * @Exception 
    ***/ 
    public void execute(SchedulableContext SC) {
        // Reschedule FIRST to ensure next run is secured before any other processing
        // (prevents losing the chain if Watchdog enqueue fails or job is interrupted)
        try {
            if (Test.isRunningTest() && simulateRescheduleFailure) {
                throw new AsyncSchedulerSelfReschedulingTestException('Simulated reschedule failure');
            }
            Integer freq = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
            if (freq == null || freq <= 0) freq = 1;
            DateTime runTime = DateTime.now().addMinutes(freq);
            String cron = '0 ' + runTime.minute() + ' ' + runTime.hour() + ' ' + runTime.day()
                + ' ' + runTime.month() + ' ? ' + runTime.year();
            System.schedule(JOB_NAME, cron, new AsyncSchedulerSelfRescheduling());
        } catch (Exception ex) {
            // System.debug('AsyncSchedulerSelfRescheduling: Failed to reschedule. ' + ex.getMessage());
        }
        // Launch Watchdog
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            // System.debug('AsyncSchedulerSelfRescheduling: Cannot launch Watchdog, limit reached.');
            return;
        }
        try {
            if (Test.isRunningTest() && simulateEnqueueFailure) {
                throw new AsyncSchedulerSelfReschedulingTestException('Simulated for coverage');
            }
            System.enqueueJob(new AsyncWatchdogQueueable());
        } catch (Exception e) {
            String errorType = e.getTypeName();
            if (errorType.contains('FlexQueue') || errorType.contains('LimitException')) {
                // System.debug('AsyncSchedulerSelfRescheduling: Flex Queue full or limit reached. ' + e.getMessage());
            } else {
                // System.debug('AsyncSchedulerSelfRescheduling: ' + e.getMessage());
            }
        }
    }

    @TestVisible private class AsyncSchedulerSelfReschedulingTestException extends Exception {}
}