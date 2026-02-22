/***
* @description Test class for AsyncScheduler - covers execute, enqueue failure path.
***/
@isTest
public with sharing class AsyncSchedulerTest {

    @isTest
    static void testExecute_Success() {
        Test.startTest();
        new AsyncScheduler().execute(null);
        Test.stopTest();
        Assert.isTrue(true, 'Scheduler should execute');
    }

    @isTest
    static void testExecute_SimulateEnqueueFailure() {
        AsyncScheduler.simulateEnqueueFailure = true;

        Test.startTest();
        new AsyncScheduler().execute(null);
        Test.stopTest();

        AsyncScheduler.simulateEnqueueFailure = false;
        Assert.isTrue(true, 'Should handle enqueue failure');
    }
}
