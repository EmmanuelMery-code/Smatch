/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Watchdog Queueable that monitors the state of active workers. If no worker is active
*              AND no Worker run is scheduled for the next n minutes (Scheduler_Frequency_Minutes),
*              publishes a Platform Event to wake up the asynchronous system.
***/ 
public with sharing class AsyncWatchdogQueueable implements Queueable {
    @TestVisible private static Boolean simulateActiveWorker = false;
    @TestVisible private static String testWorkerClassNameOverride = null;
    @TestVisible private static Boolean testForcePublishWakeUp = false;

    /*** 
    * @description Checks the state of active workers and publishes a wake-up event if necessary
    * @param context The Queueable context provided by Salesforce
    * @return 
    * @Exception 
    ***/ 
    public void execute(QueueableContext context) {
        // Dynamic retrieval of class name to handle namespaces
        String workerClassName = (Test.isRunningTest() && testWorkerClassNameOverride != null)
            ? testWorkerClassNameOverride
            : AsyncWorkerQueueable.class.getName();

        // AsyncApexJob sometimes stores the short name without namespace, so we extract the simple name
        // Protection against unexpected formats
        if (String.isNotBlank(workerClassName) && workerClassName.contains('.')) {
            Integer lastDotIndex = workerClassName.lastIndexOf('.');
            if (lastDotIndex >= 0 && lastDotIndex < workerClassName.length() - 1) {
                workerClassName = workerClassName.substring(lastDotIndex + 1);
            }
        }

        List<AsyncApexJob> activeWorkers = [
            SELECT Id FROM AsyncApexJob 
            WHERE ApexClass.Name = :workerClassName 
            AND Status IN ('Queued', 'Processing', 'Preparing', 'Holding') 
            LIMIT 1
        ];

        if (Test.isRunningTest() && simulateActiveWorker) {
            return;
        }
        if (!(Test.isRunningTest() && testForcePublishWakeUp)) {
            if (!activeWorkers.isEmpty()) {
                return;
            }
        }

        // Check if a Worker run is already scheduled for the near future (via AsyncWorkerScheduler)
        // Prevents Watchdog from starting Workers more frequently than Scheduler_Frequency_Minutes
        Integer freqMinutes = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
        DateTime cutoff = DateTime.now().addMinutes(freqMinutes);

        List<CronTrigger> scheduledWorkerRuns = [
            SELECT Id, NextFireTime FROM CronTrigger
            WHERE CronJobDetail.JobType = '7'
            AND CronJobDetail.Name LIKE 'AsyncWorker%'
            AND NextFireTime <= :cutoff
            AND NextFireTime >= :DateTime.now()
            LIMIT 1
        ];

        if (!(Test.isRunningTest() && testForcePublishWakeUp)) {
            if (!scheduledWorkerRuns.isEmpty()) {
                System.debug('AsyncWatchdogQueueable: Worker already scheduled for ' + scheduledWorkerRuns[0].NextFireTime + '. Skipping WAKEUP.');
                return;
            }
        }

        // No active Worker and no upcoming scheduled run -> publish WAKEUP
        EventBus.publish(new Async_WakeUp__e(
            Event_Type__c = 'WAKEUP'
        ));
    }
}