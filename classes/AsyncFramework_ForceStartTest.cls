/***
* @description Test class for AsyncFramework_ForceStart invocable action.
***/
@isTest
public with sharing class AsyncFramework_ForceStartTest {

    @isTest
    static void testForceStart_Success() {
        List<AsyncFramework_ForceStart.FlowResult> results = AsyncFramework_ForceStart.forceStart();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testForceStart_SimulateOuterException() {
        AsyncFramework_ForceStart.simulateOuterException = true;

        List<AsyncFramework_ForceStart.FlowResult> results = AsyncFramework_ForceStart.forceStart();

        AsyncFramework_ForceStart.simulateOuterException = false;
        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('Simulated') || results[0].message.contains('Error'));
    }

    @isTest
    static void testForceStart_SimulateWorkerEnqueueFailure() {
        AsyncFramework_ForceStart.simulateWorkerEnqueueFailure = true;

        List<AsyncFramework_ForceStart.FlowResult> results = AsyncFramework_ForceStart.forceStart();

        AsyncFramework_ForceStart.simulateWorkerEnqueueFailure = false;
        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testForceStart_SimulateWatchdogEnqueueFailure() {
        AsyncFramework_ForceStart.simulateWatchdogEnqueueFailure = true;

        List<AsyncFramework_ForceStart.FlowResult> results = AsyncFramework_ForceStart.forceStart();

        AsyncFramework_ForceStart.simulateWatchdogEnqueueFailure = false;
        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testForceStart_SimulateScheduleFailure() {
        AsyncFramework_ForceStart.simulateScheduleFailure = true;
        AsyncSchedulerSetup.removeExistingSchedules();

        List<AsyncFramework_ForceStart.FlowResult> results = AsyncFramework_ForceStart.forceStart();

        AsyncFramework_ForceStart.simulateScheduleFailure = false;
        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testForceStart_WithSchedulerAlreadyActive() {
        String jobId = System.schedule('Async Framework Scheduler Test', '0 0 * * * ?', new AsyncScheduler());

        List<AsyncFramework_ForceStart.FlowResult> results = AsyncFramework_ForceStart.forceStart();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('Active') || results[0].message.contains('Scheduler'));
    }
}
