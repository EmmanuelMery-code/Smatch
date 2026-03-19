trigger AsyncWakeUpTrigger on Async_WakeUp__e (after insert) {
    Boolean shouldWakeUpWorker = false;
    Integer reduceBatchSizeNewSize = null;
    Integer reduceBatchSizeWorkersCount = 0;
    Integer parallelWorkersToSpawn = 0;

    for (Async_WakeUp__e evt : Trigger.New) {
        // System.debug('TRIGGER WAKEUP - Type reçu : ' + evt.Event_Type__c);

        if (evt.Event_Type__c == 'PARALLEL_WORKERS') {
            Integer requested = (evt.Batch_Size__c != null && evt.Batch_Size__c >= 1) ? evt.Batch_Size__c.intValue() : 0;
            parallelWorkersToSpawn = Math.min(requested, 64);
            continue;
        }

        if (evt.Event_Type__c == 'REDUCE_BATCH_SIZE') {
            Integer newSize = 1;
            if (evt.Batch_Size__c != null && evt.Batch_Size__c >= 1) {
                newSize = evt.Batch_Size__c.intValue();
            } else if (String.isNotBlank(evt.Error_Message__c)) {
                try {
                    newSize = Integer.valueOf(evt.Error_Message__c.trim());
                } catch (Exception e) { newSize = 1; }
            }
            Integer workersCount = (evt.Workers_Count__c != null && evt.Workers_Count__c >= 0) ? evt.Workers_Count__c.intValue() : 0;
            reduceBatchSizeNewSize = newSize;
            reduceBatchSizeWorkersCount = workersCount;

            Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
            if (rtc == null) rtc = new Async_Runtime_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
            rtc.Max_Batch_Size_Override__c = newSize;
            Integer maxWorkers = AsyncFrameworkConfig.getMaxNumberWorker();
            Integer targetWorkers = Math.min(Math.max(1, workersCount) * 2, maxWorkers);
            rtc.Active_Worker_Count__c = targetWorkers;
            upsert rtc;
            // System.debug('AsyncWakeUpTrigger: Max_Batch_Size reduced to ' + newSize + ', workers=' + workersCount + ', target=' + targetWorkers);
            continue;
        }

        if (String.isBlank(evt.Event_Type__c) || evt.Event_Type__c == 'WAKEUP') {
            shouldWakeUpWorker = true;
            break;
        }
    }

    // When PARALLEL_WORKERS: spawn N workers for low effectiveLimit classes (max 64, 50 per tx)
    if (parallelWorkersToSpawn > 0) {
        Integer queueableSlots = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
        Integer toEnqueue = Math.min(Math.min(parallelWorkersToSpawn, queueableSlots), 50);
        for (Integer i = 0; i < toEnqueue; i++) {
            System.enqueueJob(new AsyncWorkerQueueable());
        }
        // System.debug('AsyncWakeUpTrigger: PARALLEL_WORKERS - enqueued ' + toEnqueue + ' workers');
    }

    // When REDUCE_BATCH_SIZE: double workers (capped at Max_Number_Worker) and start new ones with the reduced batch size
    if (reduceBatchSizeNewSize != null && reduceBatchSizeNewSize >= 1) {
        Integer maxWorkers = Math.min(64, AsyncFrameworkConfig.getMaxNumberWorker());
        Integer targetWorkers = Math.min(reduceBatchSizeWorkersCount * 2, maxWorkers);
        Integer workersToStart = Math.max(0, targetWorkers - reduceBatchSizeWorkersCount);
        Integer queueableSlots = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
        Integer toEnqueue = Math.min(Math.min(workersToStart, queueableSlots), 50);
        for (Integer i = 0; i < toEnqueue; i++) {
            System.enqueueJob(new AsyncWorkerQueueable());
        }
        // System.debug('AsyncWakeUpTrigger: Started ' + toEnqueue + ' new workers (target=' + targetWorkers + ', max=' + maxWorkers + ')');
    }

    if (shouldWakeUpWorker && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
        System.enqueueJob(new AsyncWorkerQueueable());
    }
}