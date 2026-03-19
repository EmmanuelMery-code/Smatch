/***
* @description Test class for AsyncFramework_Diagnostic invocable action.
***/
@isTest
public with sharing class AsyncFramework_DiagnosticTest {

    @TestSetup
    static void makeData() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncCleanupTask',
            Scheduled_Time__c = System.now().addHours(1),
            Executed__c = false,
            label__c = 'Test'
        );
        insert task;

        SF_Async__c statsTask = new SF_Async__c(
            Task_Class_Name__c = 'AsyncStatisticsTask',
            Scheduled_Time__c = System.now().addHours(2),
            Executed__c = false,
            label__c = 'Daily Stat'
        );
        insert statsTask;

        String longMsg = '';
        for (Integer i = 0; i < 150; i++) longMsg += 'A';
        SF_Async_Log__c errLog = new SF_Async_Log__c(
            SF_Async__c = task.Id,
            Status__c = 'Error',
            Message__c = longMsg
        );
        insert errLog;
    }

    @isTest
    static void testRunDiagnostic() {
        List<AsyncFramework_Diagnostic.FlowResult> results = AsyncFramework_Diagnostic.runDiagnostic();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testRunDiagnostic_WithSchedulersAndWorkers() {
        AsyncSchedulerSetup.removeExistingSchedules();
        AsyncWorkerScheduler.scheduleInMinutes(5);
        System.enqueueJob(new AsyncWorkerQueueable());

        List<AsyncFramework_Diagnostic.FlowResult> results = AsyncFramework_Diagnostic.runDiagnostic();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('WATCHDOG') || results[0].message.contains('WORKER') || results[0].message.length() > 50);
    }

    @isTest
    static void testRunDiagnostic_EmptyData() {
        delete [SELECT Id FROM SF_Async__c];
        delete [SELECT Id FROM SF_Async_Log__c];
        AsyncSchedulerSetup.removeExistingSchedules();

        List<AsyncFramework_Diagnostic.FlowResult> results = AsyncFramework_Diagnostic.runDiagnostic();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testRunDiagnostic_TaskWithNullLabel() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncCleanupTask',
            Scheduled_Time__c = System.now(),
            Executed__c = true,
            label__c = null
        );
        insert task;

        List<AsyncFramework_Diagnostic.FlowResult> results = AsyncFramework_Diagnostic.runDiagnostic();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testRunDiagnostic_SimulateException() {
        AsyncFramework_Diagnostic.testSimulateException = true;

        List<AsyncFramework_Diagnostic.FlowResult> results = AsyncFramework_Diagnostic.runDiagnostic();

        AsyncFramework_Diagnostic.testSimulateException = false;
        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('Simulated') || results[0].message.contains('Error'));
    }

    @isTest
    static void testRunDiagnostic_ErrorLogWithNullMessage() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncCleanupTask',
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            label__c = 'Test'
        );
        insert task;
        SF_Async_Log__c errLog = new SF_Async_Log__c(
            SF_Async__c = task.Id,
            Status__c = 'Error',
            Message__c = null
        );
        insert errLog;

        List<AsyncFramework_Diagnostic.FlowResult> results = AsyncFramework_Diagnostic.runDiagnostic();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(String.isNotBlank(results[0].message));
    }
}
