/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Main Queueable Worker that executes asynchronous tasks. Uses smart batching
*              based on historical performance to optimize the number of tasks processed per execution.
*              Stops after each run and reschedules itself based on Scheduler_Frequency_Minutes
*              from Async_Framework_Configuration__mdt metadata.
*              When Max_Tasks_Per_Run_Learned is 1 or low, spawns parallel workers (max 64) to process
*              multiple tasks concurrently, then returns to single-worker mode.
* @channels Platform Event publié : Async_WakeUp__e (/event/Async_WakeUp__e)
*          - Event_Type__c WAKEUP, ERROR, REDUCE_BATCH_SIZE, PARALLEL_WORKERS
***/ 
public with sharing class AsyncWorkerQueueable implements Queueable, Database.AllowsCallouts {

    @TestVisible private static Boolean testAllowScheduleNextRun = false;
    @TestVisible private static Boolean testAllowChainSpawn = false;
    /** When set, use this instead of getDmlSafeThreshold() to trigger reduceBatchSizeAndPublish path. */
    @TestVisible private static Integer testDmlSafeThreshold = null;
    /** When true, reduceBatchSizeAndPublish throws before EventBus.publish to test fallback path. */
    @TestVisible private static Boolean testSimulateReduceEventFail = false;
    /** When true, chain spawn enqueue throws to test scheduleNextRun as last-in-chain. */
    @TestVisible private static Boolean testSimulateChainSpawnFail = false;
    /** When set, use instead of getCpuReserveMs() to trigger CPU limit break (e.g. 999999). */
    @TestVisible private static Integer testCpuReserveMs = null;
    /** When true, scheduleNextRun throws in try block to test catch/finally. */
    @TestVisible private static Boolean testSimulateScheduleFail = false;
    /** When true, allow parallel spawn block to run in test (for coverage). */
    @TestVisible private static Boolean testAllowParallelBlock = false;
    /** When true, reduceBatchSizeAndPublish inner fallback (setMaxBatchSizeOverride) throws. */
    @TestVisible private static Boolean testSimulateSetMaxBatchSizeFail = false;
    /** When true, learnMaxTasksPerRunForClass throws to cover catch. */
    @TestVisible private static Boolean testSimulateLearnFail = false;
    /** When true, save block throws to test reducedBatchSize + save fail path. */
    @TestVisible private static Boolean testSimulateSaveFailure = false;
    /** When true, aggregate query in taskLimit block throws. */
    @TestVisible private static Boolean testSimulateAggregateFail = false;
    /** When true, parallel block inner COUNT fails. */
    @TestVisible private static Boolean testSimulatePendingCountFail = false;
    /** When true, AsyncApexJob count in parallel block fails. */
    @TestVisible private static Boolean testSimulateAsyncApexJobCountFail = false;

    private static final Integer PARALLEL_MAX_WORKERS = 64;    // never exceed 64 workers
    private static final Integer ENQUEUE_LIMIT_PER_TX = 50;    // Salesforce limit for enqueueJob per transaction
    /** Trial/Dev orgs: max chain depth 5. Cap workers to avoid "Maximum stack depth" AsyncException. */
    private static final Integer CHAIN_DEPTH_SAFE_LIMIT = 4;

    /** When > 0: this worker is part of a chain, enqueue 1 child with (chainRemaining-1) then process. Avoids Platform Event delay. */
    private final Integer chainSpawnRemaining;

    public AsyncWorkerQueueable() {
        this.chainSpawnRemaining = null;
    }
    public AsyncWorkerQueueable(Integer chainSpawnRemaining) {
        this.chainSpawnRemaining = chainSpawnRemaining;
    }

    // Configuration constants are now retrieved from Custom Metadata via AsyncFrameworkConfig
    // This allows configuration changes without code deployment and does not consume SOQL queries

    /*** 
    * @description Executes pending asynchronous tasks with smart batching and error handling
    * @param context The Queueable context provided by Salesforce
    * @return 
    * @Exception 
    ***/ 
    public void execute(QueueableContext context) {
        // Identification du worker pour les logs : ROOT (scheduler/Force Start) ou PARALLEL (chaîne)
        String jobIdStr = context != null ? String.valueOf(context.getJobId()) : 'unknown';
        if (chainSpawnRemaining != null) {
            // System.debug('AsyncWorkerQueueable: [PARALLEL] chainRemaining=' + chainSpawnRemaining + ' jobId=' + jobIdStr);
        } else {
            // System.debug('AsyncWorkerQueueable: [ROOT] jobId=' + jobIdStr);
        }

        // NOTE: Chain/parallel spawn moved to END of execute - enqueueJob before callout causes
        // "You have uncommitted work pending" and blocks task execution (e.g. CalculatorCalloutTask).

        // Identifying the next task class to process
        List<SF_Async__c> nextTaskIndicator = [
            SELECT Task_Class_Name__c, Tasks_Per_Worker_Limit__c
            FROM SF_Async__c 
            WHERE Executed__c = FALSE 
            AND Cancelled__c = FALSE
            AND Scheduled_Time__c <= :System.now()
            ORDER BY Scheduled_Time__c ASC, Execution_Order__c ASC
            LIMIT 1
        ];

        if (nextTaskIndicator.isEmpty()) {
            AsyncFrameworkConfig.clearMaxBatchSizeOverride();  // Scale down to 1 worker when no tasks left
            scheduleNextRun();
            return;
        }

        String targetClass = nextTaskIndicator[0].Task_Class_Name__c;

        // Dynamic calculation of batch size based on historical performance
        List<SF_Async_Performance__c> perfs = [
            SELECT Average_CPU__c, Max_Tasks_Per_Run_Learned__c
            FROM SF_Async_Performance__c 
            WHERE Name = :targetClass 
            LIMIT 1
        ];
        
        Decimal avgCpuCost = AsyncFrameworkConfig.getDefaultCpuCostMs();
        
        if (!perfs.isEmpty() && perfs[0].Average_CPU__c != null) {
            avgCpuCost = perfs[0].Average_CPU__c;
        }
        
        // Formula: (Available CPU time) / (Average time per task)
        Integer dynamicLimit = Integer.valueOf(AsyncFrameworkConfig.getSafeCpuLimit() / avgCpuCost);
        
        if (dynamicLimit < AsyncFrameworkConfig.getMinBatchSize()) dynamicLimit = AsyncFrameworkConfig.getMinBatchSize();
        if (dynamicLimit > AsyncFrameworkConfig.getMaxBatchSize()) dynamicLimit = AsyncFrameworkConfig.getMaxBatchSize();

        // Cap by Tasks_Per_Worker_Limit__c (per-task override) or metadata default
        // Use MIN across pending tasks so parallelization triggers when any task has a low limit
        Integer taskLimitFirst = nextTaskIndicator[0].Tasks_Per_Worker_Limit__c != null
            ? nextTaskIndicator[0].Tasks_Per_Worker_Limit__c.intValue()
            : AsyncFrameworkConfig.getTasksPerWorkerDefault();
        Integer taskLimitMin = taskLimitFirst;
        Integer pendingCount = 0;
        try {
            if (Test.isRunningTest() && testSimulateAggregateFail) throw new QueryException('Simulated aggregate fail');
            List<AggregateResult> arList = [SELECT MIN(Tasks_Per_Worker_Limit__c) minLim, COUNT(Id) cnt FROM SF_Async__c
                WHERE Executed__c = FALSE AND Cancelled__c = FALSE
                AND Scheduled_Time__c <= :System.now() AND Task_Class_Name__c = :targetClass];
            if (!arList.isEmpty()) {
                if (arList[0].get('minLim') != null) {
                    Integer minFromTasks = ((Decimal)arList[0].get('minLim')).intValue();
                    if (minFromTasks >= 1) taskLimitMin = Math.min(taskLimitFirst, minFromTasks);
                }
                pendingCount = ((Decimal)arList[0].get('cnt')).intValue();
            }
        } catch (Exception e) {
            // System.debug('AsyncWorkerQueueable: Aggregate failed. ' + e.getMessage());
        }
        Integer taskLimit = taskLimitMin;
        Integer effectiveLimit = Math.min(dynamicLimit, Math.max(1, taskLimit));

        // Cap by learned limit (from callout/DML ordering errors)
        if (!perfs.isEmpty() && perfs[0].Max_Tasks_Per_Run_Learned__c != null && perfs[0].Max_Tasks_Per_Run_Learned__c >= 1) {
            effectiveLimit = Math.min(effectiveLimit, perfs[0].Max_Tasks_Per_Run_Learned__c.intValue());
        }

        // System.debug('SMART BATCHING | Class: ' + targetClass + ' | AvgCost: ' + avgCpuCost + 'ms | BatchLimit: ' + effectiveLimit + (effectiveLimit < dynamicLimit ? ' (capped)' : ''));

        // Spawn parallel when effectiveLimit low (task/learned limit) and more work pending. Threshold from metadata (default 10).
        Integer parallelThreshold = AsyncFrameworkConfig.getParallelLowThreshold();
        Boolean shouldSpawnParallel = effectiveLimit <= parallelThreshold;
        Integer workersToSpawn = 0;
        // Skip parallel spawn if we're a chained worker (already part of parallel batch)
        Boolean isRootWorker = (chainSpawnRemaining == null);
        if (shouldSpawnParallel && (!Test.isRunningTest() || testAllowParallelBlock) && isRootWorker) {
            // System.debug('SMART BATCHING | ROOT worker entering parallel block');
            // Root worker: always requery pendingCount for parallel decision (aggregate may fail or return 0)
            try {
                if (Test.isRunningTest() && testSimulatePendingCountFail) throw new QueryException('Simulated COUNT fail');
                pendingCount = [SELECT COUNT() FROM SF_Async__c
                    WHERE Executed__c = FALSE AND Cancelled__c = FALSE
                    AND Scheduled_Time__c <= :System.now()
                    AND Task_Class_Name__c = :targetClass];
            } catch (Exception e3) {
                // System.debug('AsyncWorkerQueueable: COUNT for pendingCount failed. ' + e3.getMessage());
            }
            // System.debug('SMART BATCHING | shouldSpawnParallel=true (effectiveLimit=' + effectiveLimit
            //     + ', threshold=' + parallelThreshold + ', pendingCount=' + pendingCount + ')');
            if (pendingCount <= effectiveLimit) {
                // System.debug('SMART BATCHING | SKIP parallel: pendingCount (' + pendingCount + ') <= effectiveLimit (' + effectiveLimit + ')');
            }
            if (pendingCount > effectiveLimit) {
                Integer maxAllowed = Math.min(PARALLEL_MAX_WORKERS, AsyncFrameworkConfig.getMaxNumberWorker());
                Integer currentWorkers = 1;
                try {
                    if (Test.isRunningTest() && testSimulateAsyncApexJobCountFail) throw new QueryException('Simulated AsyncApexJob count fail');
                    Integer cnt = [SELECT COUNT() FROM AsyncApexJob
                        WHERE JobType = 'Queueable' AND ApexClass.Name = 'AsyncWorkerQueueable'
                        AND Status IN ('Queued', 'Preparing', 'Processing')];
                    currentWorkers = Math.max(1, cnt);  // at least self (may not be in table yet)
                } catch (Exception e) {
                    // System.debug('AsyncWorkerQueueable: AsyncApexJob count failed, using 1. ' + e.getMessage());
                }
                workersToSpawn = Math.max(0, Math.min(
                    Math.min(pendingCount - effectiveLimit, maxAllowed - currentWorkers),
                    Math.min(ENQUEUE_LIMIT_PER_TX - 1, CHAIN_DEPTH_SAFE_LIMIT)
                ));
                // System.debug('SMART BATCHING | workersToSpawn=' + workersToSpawn + ' (pending=' + pendingCount + ', currentWorkers=' + currentWorkers + ', maxAllowed=' + maxAllowed + ')');
                // Defer enqueueJob to END - doing it here blocks callouts with "uncommitted work" error
            }
        }

        // Selecting tasks to process - FOR UPDATE ensures no other worker processes the same records
        // Note: ORDER BY not allowed with FOR UPDATE (Id order implied)
        List<SF_Async__c> tasksToRun;
        try {
            tasksToRun = [
                SELECT Id, Name, Task_Class_Name__c, Target_Record_Id__c, 
                       Tries__c, Before_Cancelling__c, Scheduled_Time__c
                FROM SF_Async__c
                WHERE Executed__c = FALSE 
                AND Cancelled__c = FALSE
                AND Scheduled_Time__c <= :System.now()
                AND Task_Class_Name__c = :targetClass
                LIMIT :effectiveLimit
                FOR UPDATE
            ];
        } catch (QueryException qe) {
            if (qe.getMessage() != null && qe.getMessage().contains('Record Currently Unavailable')) {
                // System.debug('AsyncWorkerQueueable: Record lock contention, worker stopping. ' + qe.getMessage());
                return;
            }
            throw qe;
        }

        // Executing tasks
        List<SF_Async__c> tasksToUpdate = new List<SF_Async__c>();
        List<SF_Async_Log__c> logsToInsert = new List<SF_Async_Log__c>();
        List<Async_WakeUp__e> errorEventsToPublish = new List<Async_WakeUp__e>();

        // Optimization: retrieving Type only once outside the loop
        Type taskType = Type.forName(targetClass);
        Boolean reducedBatchSize = false;

        for (SF_Async__c taskRecord : tasksToRun) {
            // Protection against CPU Time Limit
            Integer cpuReserve = testCpuReserveMs != null ? testCpuReserveMs : AsyncFrameworkConfig.getCpuReserveMs();
            if (Limits.getCpuTime() >= (Limits.getLimitCpuTime() - cpuReserve)) {
                // System.debug('CPU Warning: Stopping batch early to preserve limits.');
                break; 
            }

            // Protection against DML limit - stop before hitting 10,000 to allow save + reduce event
            Integer dmlThreshold = testDmlSafeThreshold != null ? testDmlSafeThreshold : AsyncFrameworkConfig.getDmlSafeThreshold();
            if (Limits.getDmlRows() >= dmlThreshold) {
                // System.debug('DML Warning: Approaching limit (' + Limits.getDmlRows() + '). Stopping and reducing batch size.');
                reduceBatchSizeAndPublish(effectiveLimit);
                reducedBatchSize = true;
                break;
            }

            // Capturing metrics before execution to calculate deltas
            Integer startCpu = Limits.getCpuTime();
            Integer startSoql = Limits.getQueries();
            Integer startHeap = Limits.getHeapSize();

            SF_Async_Log__c log = new SF_Async_Log__c();
            log.SF_Async__c = taskRecord.Id;
            taskRecord.Tries__c = (taskRecord.Tries__c == null ? 0 : taskRecord.Tries__c) + 1;

            try {
                // Type.forName() throws an exception if the class doesn't exist, so no need to check null
                IAsyncTask taskInstance = (IAsyncTask) taskType.newInstance();
                taskInstance.run(taskRecord);
                
                taskRecord.Executed__c = true;
                log.Status__c = 'Success';
                log.Message__c = 'Task executed successfully.';

            } catch (Exception e) {
                log.Status__c = 'Error';
                String fullErrorMessage = e.getMessage() + '\n' + e.getStackTraceString();
                log.Message__c = fullErrorMessage;

                if (e instanceof LimitException && e.getMessage() != null && e.getMessage().contains('DML')) {
                    reduceBatchSizeAndPublish(effectiveLimit);
                    reducedBatchSize = true;
                    break;
                }

                // Learn from callout/DML ordering errors (e.g. "uncommitted work") - cap this class to 1 task per run
                if (isCalloutDmlOrderingError(e)) {
                    learnMaxTasksPerRunForClass(targetClass, 1);
                    break;  // Next run will use Max_Tasks_Per_Run_Learned__c = 1 for this class
                }

                // Publishing event for real-time investigation
                errorEventsToPublish.add(new Async_WakeUp__e(
                    Event_Type__c = 'ERROR',
                    Class_Name__c = taskRecord.Task_Class_Name__c,
                    Error_Message__c = fullErrorMessage.left(32768),
                    Related_Record_Id__c = taskRecord.Id,
                    Target_Record_Id__c = taskRecord.Target_Record_Id__c
                ));
            }

            // Calculating metrics (deltas)
            log.CPU_Time__c = Limits.getCpuTime() - startCpu;
            log.SOQL_Queries__c = Limits.getQueries() - startSoql;
            log.Heap_Size__c = Limits.getHeapSize() - startHeap;

            logsToInsert.add(log);
            tasksToUpdate.add(taskRecord);
        }

        // Saving with partial error handling (allOrNone=false)
        try {
            if (Test.isRunningTest() && testSimulateSaveFailure) throw new AsyncException('Simulated save failure');
            if (!errorEventsToPublish.isEmpty()) EventBus.publish(errorEventsToPublish);
            if (!logsToInsert.isEmpty()) Database.insert(logsToInsert, false);
            if (!tasksToUpdate.isEmpty()) Database.update(tasksToUpdate, false);
        } catch (Exception e) {
            // System.debug('AsyncWorkerQueueable: Save failed (possible DML limit). ' + e.getMessage());
            if (reducedBatchSize) {
                scheduleNextRun();
                return;
            }
            throw e;
        }

        // Restore Max_Batch_Size to metadata value only on full success (no early break / no DML reduce)
        if (!reducedBatchSize) {
            AsyncFrameworkConfig.clearMaxBatchSizeOverride();
        }

        // Chain spawn AFTER tasks+DML - enqueueJob before callout causes "uncommitted work" error
        Boolean chainSpawnSucceeded = false;
        if (chainSpawnRemaining != null && chainSpawnRemaining > 0 && (!Test.isRunningTest() || testAllowChainSpawn)
                && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            try {
                if (Test.isRunningTest() && testSimulateChainSpawnFail) throw new AsyncException('Simulated chain spawn fail');
                Id childJobId = System.enqueueJob(new AsyncWorkerQueueable(chainSpawnRemaining - 1));
                // System.debug('AsyncWorkerQueueable: [PARALLEL_SPAWN] childJobId=' + childJobId + ' remaining=' + (chainSpawnRemaining - 1));
                chainSpawnSucceeded = true;
            } catch (Exception e) {
                // System.debug('AsyncWorkerQueueable: Chain spawn failed. ' + e.getMessage());
                // Si "Maximum stack depth" (Trial/Dev limit ~5), on devient le dernier : on doit rescheduler.
            }
        }

        // Parallel spawn AFTER tasks+DML - same "uncommitted work" constraint
        if (workersToSpawn > 0 && !Test.isRunningTest() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            try {
                Id firstChildId = System.enqueueJob(new AsyncWorkerQueueable(workersToSpawn - 1));
                // System.debug('AsyncWorkerQueueable: [PARALLEL_START] firstChildJobId=' + firstChildId + ' total=' + workersToSpawn + ' class=' + targetClass);
            } catch (Exception e) {
                // System.debug('AsyncWorkerQueueable: Chain parallel failed, fallback to Platform Event. ' + e.getMessage());
                try {
                    EventBus.publish(new Async_WakeUp__e(
                        Event_Type__c = 'PARALLEL_WORKERS',
                        Batch_Size__c = workersToSpawn,
                        Class_Name__c = targetClass,
                        Error_Message__c = 'Spawn ' + workersToSpawn + ' workers for ' + pendingCount + ' pending'
                    ));
                } catch (Exception e2) {
                    workersToSpawn = 0;
                }
            }
        }

        // Self-reschedule: skip when we spawned parallel workers, or we're mid-chain (not the last).
        // Last worker (chainSpawnRemaining=0) or non-chained worker without spawn calls scheduleNextRun().
        // IMPORTANT: si chain spawn a échoué (ex: "Maximum stack depth"), on devient le dernier : on DOIT rescheduler.
        Boolean isLastInChain = (chainSpawnRemaining == null || chainSpawnRemaining == 0 || !chainSpawnSucceeded);
        if (workersToSpawn <= 0 && isLastInChain) {
            scheduleNextRun();
        }
    }

    /*** 
    * @description Publishes REDUCE_BATCH_SIZE event so the trigger can halve Max_Batch_Size override.
    *              Includes batch size and number of workers in progress.
    * @param currentBatchSize The current dynamic limit used for this run
    * @return 
    * @Exception 
    ***/ 
    private void reduceBatchSizeAndPublish(Integer currentBatchSize) {
        Integer reduced = Math.max(1, currentBatchSize / 2);
        if (reduced >= currentBatchSize) return;
        try {
            if (Test.isRunningTest() && testSimulateReduceEventFail) throw new AsyncException('Simulated EventBus fail');
            Integer workersCount = 1;
            if (!Test.isRunningTest()) {
                Integer queryCount = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable' AND ApexClass.Name = 'AsyncWorkerQueueable' AND Status IN ('Queued', 'Preparing', 'Processing')];
                Integer storedCount = AsyncFrameworkConfig.getActiveWorkerCount();
                workersCount = (storedCount != null && storedCount > queryCount) ? storedCount : Math.max(1, queryCount);
            }
            // System.debug('AsyncWorkerQueueable: About to publish REDUCE_BATCH_SIZE - batchSize=' + reduced + ', workers=' + workersCount);
            EventBus.publish(new Async_WakeUp__e(
                Event_Type__c = 'REDUCE_BATCH_SIZE',
                Batch_Size__c = reduced,
                Workers_Count__c = workersCount,
                Error_Message__c = 'Batch réduit de ' + currentBatchSize + ' à ' + reduced + '. Workers actifs: ' + workersCount
            ));
            // System.debug('AsyncWorkerQueueable: REDUCE_BATCH_SIZE published successfully.');
        } catch (Exception e) {
            // System.debug('AsyncWorkerQueueable: EventBus.publish failed, trying fallback. ' + e.getMessage());
            try {
                if (Test.isRunningTest() && testSimulateSetMaxBatchSizeFail) throw new AsyncException('Simulated setMaxBatchSize fail');
                AsyncFrameworkConfig.setMaxBatchSizeOverride(reduced);
                // System.debug('AsyncWorkerQueueable: Fallback - Custom Setting updated directly.');
            } catch (Exception e2) {
                if (!Test.isRunningTest() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                    System.enqueueJob(new AsyncReduceBatchSizeJob(reduced));
                    // System.debug('AsyncWorkerQueueable: Fallback - AsyncReduceBatchSizeJob enqueued.');
                }
            }
        }
    }

    /*** 
    * @description Schedules the next Worker run at (now + Scheduler_Frequency_Minutes)
    *              Read from Async_Framework_Configuration__mdt metadata.
    *              Version simplifiée (parallélisme maximal). finally appelle Force Start pour garantir
    *              qu'au moins un worker reste en route même si schedule/abort a tout arrêté.
    * @param  
    * @return 
    * @Exception 
    ***/ 
    private void scheduleNextRun() {
        if (Test.isRunningTest() && !testAllowScheduleNextRun) return;

        try {
            if (Test.isRunningTest() && testSimulateScheduleFail) throw new AsyncException('Simulated schedule fail');
            AsyncSchedulerSetup.ensureWatchdogSchedulerPresent();
            String jobId = AsyncWorkerScheduler.scheduleInMinutes(null);
            Integer freqMinutes = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
            // System.debug('AsyncWorkerQueueable: Rescheduled for ' + DateTime.now().addMinutes(freqMinutes).format() + ' (' + freqMinutes + ' min)');
        } catch (Exception e) {
            // System.debug('AsyncWorkerQueueable: Failed to reschedule. Error: ' + e.getMessage());
        } finally {
            if (!Test.isRunningTest() || testAllowScheduleNextRun) {
                try {
                    AsyncFramework_ForceStart.ensureWorkerRunning();
                } catch (Exception e2) {
                    // System.debug('AsyncWorkerQueueable: ensureWorkerRunning in finally failed. ' + e2.getMessage());
                }
            }
        }
    }
    
    /*** 
    * @description Detects callout/DML ordering errors (e.g. "You have uncommitted work pending. Please commit or rollback before calling out").
    * @param e The exception to check
    * @return Boolean True if this is a callout/DML ordering error
    ***/ 
    private static Boolean isCalloutDmlOrderingError(Exception e) {
        if (e == null || e.getMessage() == null) return false;
        String msg = e.getMessage().toLowerCase();
        return (msg.contains('uncommitted work') || msg.contains('commit or rollback') || msg.contains('callout'));
    }

    /*** 
    * @description Learns and persists the max tasks per run for a class (e.g. after callout/DML ordering error).
    * @param className The task class name
    * @param maxTasks The learned max (typically 1)
    ***/ 
    private static void learnMaxTasksPerRunForClass(String className, Integer maxTasks) {
        if (String.isBlank(className) || maxTasks == null || maxTasks < 1) return;
        try {
            if (Test.isRunningTest() && testSimulateLearnFail) throw new AsyncException('Simulated learn fail');
            List<SF_Async_Performance__c> existing = [SELECT Id, Name, Max_Tasks_Per_Run_Learned__c FROM SF_Async_Performance__c WHERE Name = :className LIMIT 1];
            SF_Async_Performance__c perf = existing.isEmpty() ? new SF_Async_Performance__c(Name = className) : existing[0];
            perf.Max_Tasks_Per_Run_Learned__c = maxTasks;
            upsert perf;
            // System.debug('AsyncWorkerQueueable: Learned Max_Tasks_Per_Run_Learned__c=' + maxTasks + ' for class ' + className);
        } catch (Exception ex) {
            // System.debug('AsyncWorkerQueueable: Failed to learn Max_Tasks_Per_Run for ' + className + ' - ' + ex.getMessage());
        }
    }

    /*** 
    * @description Custom exception for asynchronous framework errors
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class AsyncException extends Exception {}
}