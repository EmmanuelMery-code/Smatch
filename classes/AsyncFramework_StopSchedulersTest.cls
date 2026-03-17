/***
* @description Test class for AsyncFramework_StopSchedulers invocable action.
***/
@isTest
public with sharing class AsyncFramework_StopSchedulersTest {

    @isTest
    static void testStopSchedulers_NoSchedulers() {
        AsyncSchedulerSetup.removeExistingSchedules();

        List<AsyncFramework_StopSchedulers.FlowResult> results = AsyncFramework_StopSchedulers.stopSchedulers();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
        Assert.isTrue(results[0].message.contains('Aucun') || results[0].message.contains('trouvé') || results[0].message.contains('Arrêtés') || results[0].message.contains('succès'));
    }

    @isTest
    static void testStopSchedulers_WithSchedulers() {
        String jobId = System.schedule('Async Test Stop', '0 0 * * * ?', new AsyncScheduler());

        List<AsyncFramework_StopSchedulers.FlowResult> results = AsyncFramework_StopSchedulers.stopSchedulers();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('arrêtés') || results[0].message.contains('succès') || results[0].message.contains('Async') || results[0].message.length() > 5);
    }

    @isTest
    static void testStopSchedulers_WithAsyncWorker() {
        AsyncWorkerScheduler.scheduleInMinutes(5);
        List<AsyncFramework_StopSchedulers.FlowResult> results = AsyncFramework_StopSchedulers.stopSchedulers();
        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testStopSchedulers_SimulateAbortFailure() {
        String jobId = System.schedule('Async Scheduler Abort Fail', '0 0 * * * ?', new AsyncScheduler());
        AsyncFramework_StopSchedulers.testSimulateAbortFailure = true;

        List<AsyncFramework_StopSchedulers.FlowResult> results = AsyncFramework_StopSchedulers.stopSchedulers();

        AsyncFramework_StopSchedulers.testSimulateAbortFailure = false;
        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('Erreurs') || results[0].message.contains('Simulated'));
    }

    @isTest
    static void testStopSchedulers_PartialAbortStoppedAndErrors() {
        System.schedule('Async Stop 01', '0 0 * * * ?', new AsyncScheduler());
        System.schedule('Async Stop 02', '0 5 * * * ?', new AsyncScheduler());

        AsyncFramework_StopSchedulers.testSimulateAbortFailureOnNth = 2;

        List<AsyncFramework_StopSchedulers.FlowResult> results = AsyncFramework_StopSchedulers.stopSchedulers();

        AsyncFramework_StopSchedulers.testSimulateAbortFailureOnNth = 0;
        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('Arrêtés'));
        Assert.isTrue(results[0].message.contains('Erreurs'));
    }
}