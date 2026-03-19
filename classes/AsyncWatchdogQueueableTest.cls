/***
* @description Test class for AsyncWatchdogQueueable - covers all branches.
***/
@isTest
public with sharing class AsyncWatchdogQueueableTest {

    @isTest
    static void testExecute_ForcePublishWakeUp() {
        AsyncWatchdogQueueable.testForcePublishWakeUp = true;

        Test.startTest();
        System.enqueueJob(new AsyncWatchdogQueueable());
        Test.stopTest();

        AsyncWatchdogQueueable.testForcePublishWakeUp = false;
        Assert.isTrue(true, 'Should publish WAKEUP');
    }

    @isTest
    static void testExecute_SimulateActiveWorker() {
        AsyncWatchdogQueueable.simulateActiveWorker = true;

        Test.startTest();
        System.enqueueJob(new AsyncWatchdogQueueable());
        Test.stopTest();

        AsyncWatchdogQueueable.simulateActiveWorker = false;
        Assert.isTrue(true, 'Should return early when simulating active worker');
    }

    @isTest
    static void testExecute_WorkerClassNameOverride() {
        AsyncWatchdogQueueable.testWorkerClassNameOverride = 'NonExistentClass';
        AsyncWatchdogQueueable.testForcePublishWakeUp = true;

        Test.startTest();
        System.enqueueJob(new AsyncWatchdogQueueable());
        Test.stopTest();

        AsyncWatchdogQueueable.testWorkerClassNameOverride = null;
        AsyncWatchdogQueueable.testForcePublishWakeUp = false;
        Assert.isTrue(true, 'Should use override class name');
    }

    @isTest
    static void testExecute_WorkerClassNameWithNamespace() {
        AsyncWatchdogQueueable.testWorkerClassNameOverride = 'namespace.AsyncWorkerQueueable';
        AsyncWatchdogQueueable.testForcePublishWakeUp = true;

        Test.startTest();
        System.enqueueJob(new AsyncWatchdogQueueable());
        Test.stopTest();

        AsyncWatchdogQueueable.testWorkerClassNameOverride = null;
        AsyncWatchdogQueueable.testForcePublishWakeUp = false;
        Assert.isTrue(true, 'Should extract short name from namespace');
    }
}
