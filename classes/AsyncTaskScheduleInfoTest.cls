/***
* @description Test class for AsyncTaskScheduleInfo invocable action.
* Covers getScheduleInfo for Flow: execution frequency, next execution time, scheduled/executed task analysis.
***/
@isTest
public with sharing class AsyncTaskScheduleInfoTest {

    private static final String TEST_CLASS = 'AsyncTaskScheduleInfoTest.TestTask';

    @TestSetup
    static void setup() {
        // Clean any existing test data for our class
        delete [SELECT Id FROM SF_Async__c WHERE Task_Class_Name__c = :TEST_CLASS];
    }

    @isTest
    static void testGetScheduleInfo_BlankTaskClassName() {
        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = '';
        req.lookbackDays = 7;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size(), 'One response expected');
        Assert.areEqual('', results[0].taskClassName);
        Assert.isTrue(results[0].message.contains('required'));
        Assert.isFalse(results[0].hasScheduledTasks);
        Assert.isNull(results[0].executionFrequencyMinutes);
    }

    @isTest
    static void testGetScheduleInfo_NullTaskClassName() {
        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = null;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].message.contains('required'));
        Assert.isFalse(results[0].hasScheduledTasks);
    }

    @isTest
    static void testGetScheduleInfo_NoData() {
        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = 'NonExistentClass';
        req.lookbackDays = 7;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.areEqual('NonExistentClass', results[0].taskClassName);
        Assert.isFalse(results[0].hasScheduledTasks);
        Assert.areEqual(0, results[0].totalScheduledTasks);
        Assert.isNull(results[0].nextExecutionDateTime);
        Assert.isNull(results[0].executionFrequencyMinutes);
        Assert.isTrue(results[0].message.contains('Insufficient') || results[0].message.contains('successfully'));
    }

    @isTest
    static void testGetScheduleInfo_ScheduledTasksOnly() {
        Datetime base = Datetime.now().addMinutes(10);
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        tasks.add(new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = base,
            Executed__c = false,
            Before_Cancelling__c = 3
        ));
        tasks.add(new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = base.addMinutes(30),
            Executed__c = false,
            Before_Cancelling__c = 3
        ));
        insert tasks;

        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = TEST_CLASS;
        req.lookbackDays = 7;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].hasScheduledTasks);
        Assert.areEqual(2, results[0].totalScheduledTasks);
        Assert.areEqual(base, results[0].nextExecutionDateTime);
        Assert.isNotNull(results[0].executionFrequencyMinutes);
        Assert.areEqual(30, results[0].executionFrequencyMinutes.intValue());
    }

    @isTest
    static void testGetScheduleInfo_ExecutedTasksOnly() {
        Datetime past = Datetime.now().addDays(-3);
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        tasks.add(new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = past,
            Executed__c = true,
            Before_Cancelling__c = 3
        ));
        tasks.add(new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = past.addMinutes(60),
            Executed__c = true,
            Before_Cancelling__c = 3
        ));
        insert tasks;

        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = TEST_CLASS;
        req.lookbackDays = 7;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isNotNull(results[0].executionFrequencyMinutes);
        Assert.areEqual(60, results[0].executionFrequencyMinutes.intValue());
        Assert.isTrue(results[0].message.contains('successfully'));
    }

    @isTest
    static void testGetScheduleInfo_OneScheduledTask() {
        Datetime future = Datetime.now().addMinutes(15);
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = future,
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert task;

        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = TEST_CLASS;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].hasScheduledTasks);
        Assert.areEqual(1, results[0].totalScheduledTasks);
        Assert.areEqual(future, results[0].nextExecutionDateTime);
        // Only 1 scheduled task: no frequency from scheduled; no executed in lookback
        Assert.isTrue(results[0].message.contains('Insufficient') || results[0].executionFrequencyMinutes != null);
    }

    @isTest
    static void testGetScheduleInfo_DefaultLookbackDays() {
        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = 'SomeClass';
        req.lookbackDays = null;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        // No exception - default 7 is used internally
    }

    @isTest
    static void testGetScheduleInfo_CustomLookbackDays() {
        Datetime past = Datetime.now().addDays(-1);
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        tasks.add(new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = past,
            Executed__c = true,
            Before_Cancelling__c = 3
        ));
        tasks.add(new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = past.addMinutes(45),
            Executed__c = true,
            Before_Cancelling__c = 3
        ));
        insert tasks;

        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = TEST_CLASS;
        req.lookbackDays = 14;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isNotNull(results[0].executionFrequencyMinutes);
        Assert.areEqual(45, results[0].executionFrequencyMinutes.intValue());
    }

    @isTest
    static void testGetScheduleInfo_ExcludesCancelledAndExecuted() {
        Datetime base = Datetime.now().addMinutes(5);
        SF_Async__c pending = new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = base,
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        SF_Async__c cancelled = new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = base.addMinutes(10),
            Executed__c = false,
            Before_Cancelling__c = 3,
            Tries__c = 3
        );
        insert new List<SF_Async__c>{ pending, cancelled };

        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = TEST_CLASS;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(1, results[0].totalScheduledTasks, 'Only pending non-cancelled should count');
        Assert.areEqual(base, results[0].nextExecutionDateTime);
    }

    @isTest
    static void testGetScheduleInfo_MultipleRequests() {
        SF_Async__c t1 = new SF_Async__c(
            Task_Class_Name__c = TEST_CLASS,
            Scheduled_Time__c = Datetime.now().addMinutes(10),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert t1;

        AsyncTaskScheduleInfo.ScheduleRequest req1 = new AsyncTaskScheduleInfo.ScheduleRequest();
        req1.taskClassName = TEST_CLASS;
        AsyncTaskScheduleInfo.ScheduleRequest req2 = new AsyncTaskScheduleInfo.ScheduleRequest();
        req2.taskClassName = 'OtherClass';

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req1, req2 });

        Assert.areEqual(2, results.size());
        Assert.isTrue(results[0].hasScheduledTasks);
        Assert.areEqual(TEST_CLASS, results[0].taskClassName);
        Assert.isFalse(results[1].hasScheduledTasks);
        Assert.areEqual('OtherClass', results[1].taskClassName);
    }

    @isTest
    static void testGetScheduleInfo_ThreeScheduledTasks() {
        Datetime base = Datetime.now().addMinutes(20);
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 3; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = TEST_CLASS,
                Scheduled_Time__c = base.addMinutes(i * 10),
                Executed__c = false,
                Before_Cancelling__c = 3
            ));
        }
        insert tasks;

        AsyncTaskScheduleInfo.ScheduleRequest req = new AsyncTaskScheduleInfo.ScheduleRequest();
        req.taskClassName = TEST_CLASS;

        List<AsyncTaskScheduleInfo.ScheduleResponse> results = AsyncTaskScheduleInfo.getScheduleInfo(
            new List<AsyncTaskScheduleInfo.ScheduleRequest>{ req });

        Assert.areEqual(3, results[0].totalScheduledTasks);
        Assert.areEqual(base, results[0].nextExecutionDateTime);
        Assert.isNotNull(results[0].executionFrequencyMinutes);
        Assert.areEqual(10, results[0].executionFrequencyMinutes.intValue());
    }
}
