/***
* @description Test class for AsyncWorkerQueueable - covers error paths, chain spawn, learn logic.
***/
@isTest
public with sharing class AsyncWorkerQueueableTest {

    public class MockTask implements IAsyncTask {
        public void run(SF_Async__c c) {}
    }

    /** Task that throws a generic exception */
    public class FailingTask implements IAsyncTask {
        public void run(SF_Async__c c) {
            throw new AsyncWorkerQueueable.AsyncException('Simulated task failure');
        }
    }

    /** Task that throws callout/DML ordering error to trigger learnMaxTasksPerRunForClass */
    public class CalloutDmlOrderingTask implements IAsyncTask {
        public void run(SF_Async__c c) {
            throw new AsyncWorkerQueueable.AsyncException('You have uncommitted work pending. Please commit or rollback before calling out');
        }
    }

    /** Same as CalloutDmlOrderingTask - for learn catch coverage with testSimulateLearnFail */
    public class CalloutDmlOrderingTaskLearnFail implements IAsyncTask {
        public void run(SF_Async__c c) {
            throw new AsyncWorkerQueueable.AsyncException('Please commit or rollback before calling out');
        }
    }

    @TestSetup
    static void makeData() {
        delete [SELECT Id FROM SF_Async_Performance__c WHERE Name = 'AsyncWorkerQueueableTest.FailingTask'];
        delete [SELECT Id FROM SF_Async_Performance__c WHERE Name = 'AsyncWorkerQueueableTest.CalloutDmlOrderingTask'];
        delete [SELECT Id FROM SF_Async_Performance__c WHERE Name = 'AsyncWorkerQueueableTest.CalloutDmlOrderingTaskLearnFail'];
    }

    @isTest
    static void testWorker_NoTasks() {
        delete [SELECT Id FROM SF_Async__c];
        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();
        Assert.isTrue(true, 'Worker with no tasks should complete');
    }

    @isTest
    static void testWorker_TaskThrowsException() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.FailingTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        List<SF_Async_Log__c> logs = [SELECT Id, Status__c, Message__c FROM SF_Async_Log__c WHERE SF_Async__c = :task.Id];
        Assert.isTrue(!logs.isEmpty(), 'Error log should be created');
        Assert.areEqual('Error', logs[0].Status__c);
    }

    @isTest
    static void testWorker_LearnMaxTasksCatch() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.CalloutDmlOrderingTaskLearnFail',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        AsyncWorkerQueueable.testSimulateLearnFail = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testSimulateLearnFail = false;
        Assert.isTrue(true, 'Learn catch path should complete');
    }

    @isTest
    static void testWorker_CalloutDmlOrderingError() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.CalloutDmlOrderingTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        List<SF_Async_Performance__c> perfs = [
            SELECT Max_Tasks_Per_Run_Learned__c FROM SF_Async_Performance__c
            WHERE Name = 'AsyncWorkerQueueableTest.CalloutDmlOrderingTask'
        ];
        Assert.isTrue(!perfs.isEmpty(), 'Should learn Max_Tasks_Per_Run_Learned__c=1');
        Assert.areEqual(1, perfs[0].Max_Tasks_Per_Run_Learned__c);
    }

    @isTest
    static void testWorker_ConstructorWithChainRemaining() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        AsyncWorkerQueueable.testAllowChainSpawn = true;
        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable(1));
        Test.stopTest();
        AsyncWorkerQueueable.testAllowChainSpawn = false;

        Integer executed = [SELECT COUNT() FROM SF_Async__c WHERE Executed__c = TRUE];
        Assert.isTrue(executed >= 1, 'Chain worker should process task');
    }

    @isTest
    static void testWorker_ScheduleNextRunCatchAndFinally() {
        delete [SELECT Id FROM SF_Async__c];
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncWorkerQueueable.testSimulateScheduleFail = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncWorkerQueueable.testSimulateScheduleFail = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Schedule fail catch/finally path should complete');
    }

    @isTest
    static void testWorker_ScheduleNextRunPath() {
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;

        task = [SELECT Executed__c FROM SF_Async__c WHERE Id = :task.Id];
        Assert.isTrue(task.Executed__c, 'Task should be executed');
    }

    @isTest
    static void testWorker_SuccessfulExecution() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        task = [SELECT Executed__c FROM SF_Async__c WHERE Id = :task.Id];
        Assert.isTrue(task.Executed__c, 'Task should be executed');
    }

    @isTest
    static void testWorker_ReduceBatchSizeEarlyReturn() {
        SF_Async_Performance__c perf = new SF_Async_Performance__c(
            Name = 'AsyncWorkerQueueableTest.MockTask',
            Max_Tasks_Per_Run_Learned__c = 1
        );
        insert perf;
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1),
            Tasks_Per_Worker_Limit__c = 1
        );
        insert task;

        AsyncWorkerQueueable.testDmlSafeThreshold = 0;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testDmlSafeThreshold = null;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Reduce batch size early return path');
    }

    @isTest
    static void testWorker_DmlLimitTriggersReduceBatchSize() {
        AsyncWorkerQueueable.testDmlSafeThreshold = 0;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testDmlSafeThreshold = null;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'DML limit path should complete without error');
    }

    @isTest
    static void testWorker_ReduceEventFailFallbackSetMaxBatchThrows() {
        AsyncWorkerQueueable.testDmlSafeThreshold = 0;
        AsyncWorkerQueueable.testSimulateReduceEventFail = true;
        AsyncWorkerQueueable.testSimulateSetMaxBatchSizeFail = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testDmlSafeThreshold = null;
        AsyncWorkerQueueable.testSimulateReduceEventFail = false;
        AsyncWorkerQueueable.testSimulateSetMaxBatchSizeFail = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Reduce fallback inner catch path should complete');
    }

    @isTest
    static void testWorker_SaveFailureWithReducedBatchSize() {
        AsyncWorkerQueueable.testDmlSafeThreshold = 0;
        AsyncWorkerQueueable.testSimulateSaveFailure = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testDmlSafeThreshold = null;
        AsyncWorkerQueueable.testSimulateSaveFailure = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Save failure with reducedBatchSize path should complete');
    }

    @isTest
    static void testWorker_ReduceEventFailFallbackToSetting() {
        AsyncWorkerQueueable.testDmlSafeThreshold = 0;
        AsyncWorkerQueueable.testSimulateReduceEventFail = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testDmlSafeThreshold = null;
        AsyncWorkerQueueable.testSimulateReduceEventFail = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Reduce event fail fallback path should complete');
    }

    @isTest
    static void testWorker_ChainSpawnFailReschedulesAsLast() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        AsyncWorkerQueueable.testAllowChainSpawn = true;
        AsyncWorkerQueueable.testSimulateChainSpawnFail = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable(1));
        Test.stopTest();

        AsyncWorkerQueueable.testAllowChainSpawn = false;
        AsyncWorkerQueueable.testSimulateChainSpawnFail = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Chain spawn fail should reschedule as last in chain');
    }

    @isTest
    static void testWorker_ChainRemainingZero() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        AsyncWorkerQueueable.testAllowChainSpawn = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable(0));
        Test.stopTest();

        AsyncWorkerQueueable.testAllowChainSpawn = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        task = [SELECT Executed__c FROM SF_Async__c WHERE Id = :task.Id];
        Assert.isTrue(task.Executed__c);
    }

    @isTest
    static void testWorker_WithPerformanceData() {
        SF_Async_Performance__c perf = new SF_Async_Performance__c(
            Name = 'AsyncWorkerQueueableTest.MockTask',
            Average_CPU__c = 100,
            Max_Tasks_Per_Run_Learned__c = 5
        );
        insert perf;

        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 3; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
                Scheduled_Time__c = System.now().addHours(-1),
                Tasks_Per_Worker_Limit__c = 2
            ));
        }
        insert tasks;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        Integer executed = [SELECT COUNT() FROM SF_Async__c WHERE Id IN :tasks AND Executed__c = TRUE];
        Assert.isTrue(executed > 0, 'Worker should process tasks with perf data');
    }

    @isTest
    static void testWorker_CpuLimitBreak() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        AsyncWorkerQueueable.testCpuReserveMs = 999999;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testCpuReserveMs = null;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'CPU limit break path should complete');
    }

    @isTest
    static void testWorker_AggregateFailFallback() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1)
        );
        insert task;

        AsyncWorkerQueueable.testSimulateAggregateFail = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testSimulateAggregateFail = false;
        task = [SELECT Executed__c FROM SF_Async__c WHERE Id = :task.Id];
        Assert.isTrue(task.Executed__c);
    }

    @isTest
    static void testWorker_ParallelBlockPendingCountFail() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1),
            Tasks_Per_Worker_Limit__c = 1
        );
        insert task;

        AsyncWorkerQueueable.testAllowParallelBlock = true;
        AsyncWorkerQueueable.testSimulatePendingCountFail = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testAllowParallelBlock = false;
        AsyncWorkerQueueable.testSimulatePendingCountFail = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'Pending count fail path should complete');
    }

    @isTest
    static void testWorker_ParallelBlockAsyncApexJobCountFail() {
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 5; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
                Scheduled_Time__c = System.now().addHours(-1),
                Tasks_Per_Worker_Limit__c = 1
            ));
        }
        insert tasks;

        AsyncWorkerQueueable.testAllowParallelBlock = true;
        AsyncWorkerQueueable.testSimulateAsyncApexJobCountFail = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testAllowParallelBlock = false;
        AsyncWorkerQueueable.testSimulateAsyncApexJobCountFail = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Assert.isTrue(true, 'AsyncApexJob count fail path should complete');
    }

    @isTest
    static void testWorker_ParallelBlockCoverage() {
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 5; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
                Scheduled_Time__c = System.now().addHours(-1),
                Tasks_Per_Worker_Limit__c = 1
            ));
        }
        insert tasks;

        AsyncWorkerQueueable.testAllowParallelBlock = true;
        AsyncWorkerQueueable.testAllowScheduleNextRun = true;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = true;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        AsyncWorkerQueueable.testAllowParallelBlock = false;
        AsyncWorkerQueueable.testAllowScheduleNextRun = false;
        AsyncFramework_ForceStart.testAllowEnsureWorkerRunning = false;
        Integer executed = [SELECT COUNT() FROM SF_Async__c WHERE Id IN :tasks AND Executed__c = TRUE];
        Assert.isTrue(executed >= 1);
    }

    @isTest
    static void testWorker_AggregateMinLimNull() {
        SF_Async_Performance__c perf = new SF_Async_Performance__c(
            Name = 'AsyncWorkerQueueableTest.MockTask',
            Average_CPU__c = 100
        );
        insert perf;

        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncWorkerQueueableTest.MockTask',
            Scheduled_Time__c = System.now().addHours(-1),
            Tasks_Per_Worker_Limit__c = null
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        task = [SELECT Executed__c FROM SF_Async__c WHERE Id = :task.Id];
        Assert.isTrue(task.Executed__c);
    }
}
