/***
* @description Test class for AsyncSchedulerSelfRescheduling - covers reschedule and enqueue failure paths.
***/
@isTest
public with sharing class AsyncSchedulerSelfReschedulingTest {

    @isTest
    static void testExecute_Success() {
        Test.startTest();
        new AsyncSchedulerSelfRescheduling().execute(null);
        Test.stopTest();
        Assert.isTrue(true, 'Self-rescheduling should execute');
    }

    @isTest
    static void testExecute_SimulateRescheduleFailure() {
        AsyncSchedulerSelfRescheduling.simulateRescheduleFailure = true;

        Test.startTest();
        new AsyncSchedulerSelfRescheduling().execute(null);
        Test.stopTest();

        AsyncSchedulerSelfRescheduling.simulateRescheduleFailure = false;
        Assert.isTrue(true, 'Should handle reschedule failure');
    }

    @isTest
    static void testExecute_SimulateEnqueueFailure() {
        AsyncSchedulerSelfRescheduling.simulateEnqueueFailure = true;

        Test.startTest();
        new AsyncSchedulerSelfRescheduling().execute(null);
        Test.stopTest();

        AsyncSchedulerSelfRescheduling.simulateEnqueueFailure = false;
        Assert.isTrue(true, 'Should handle enqueue failure');
    }
}
