/***
* @description Test class for AsyncFramework_CleanupControl invocable action.
***/
@isTest
public with sharing class AsyncFramework_CleanupControlTest {

    @isTest
    static void testControlCleanup_START() {
        AsyncFramework_CleanupControl.ControlRequest req = new AsyncFramework_CleanupControl.ControlRequest();
        req.action = 'START';

        List<AsyncFramework_CleanupControl.FlowResult> results = AsyncFramework_CleanupControl.controlCleanup(new List<AsyncFramework_CleanupControl.ControlRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('successfully') || results[0].message.contains('Days_To_Keep'));
    }

    @isTest
    static void testControlCleanup_START_DAILY_New() {
        delete [SELECT Id FROM SF_Async__c WHERE Task_Class_Name__c = 'AsyncCleanupTask'];

        AsyncFramework_CleanupControl.ControlRequest req = new AsyncFramework_CleanupControl.ControlRequest();
        req.action = 'START_DAILY';

        List<AsyncFramework_CleanupControl.FlowResult> results = AsyncFramework_CleanupControl.controlCleanup(new List<AsyncFramework_CleanupControl.ControlRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('scheduled') || results[0].message.contains('daily'));
    }

    @isTest
    static void testControlCleanup_START_DAILY_AlreadyScheduled() {
        SF_Async__c existing = new SF_Async__c(
            Task_Class_Name__c = 'AsyncCleanupTask',
            Scheduled_Time__c = System.now().addDays(1),
            Executed__c = false,
            label__c = 'Daily Cleanup'
        );
        insert existing;

        AsyncFramework_CleanupControl.ControlRequest req = new AsyncFramework_CleanupControl.ControlRequest();
        req.action = 'START_DAILY';

        List<AsyncFramework_CleanupControl.FlowResult> results = AsyncFramework_CleanupControl.controlCleanup(new List<AsyncFramework_CleanupControl.ControlRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('already scheduled'));
    }

    @isTest
    static void testControlCleanup_STOP_WithPending() {
        SF_Async__c pending = new SF_Async__c(
            Task_Class_Name__c = 'AsyncCleanupTask',
            Scheduled_Time__c = System.now().addDays(1),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert pending;

        AsyncFramework_CleanupControl.ControlRequest req = new AsyncFramework_CleanupControl.ControlRequest();
        req.action = 'STOP';

        List<AsyncFramework_CleanupControl.FlowResult> results = AsyncFramework_CleanupControl.controlCleanup(new List<AsyncFramework_CleanupControl.ControlRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('cancelled') || results[0].message.contains('stopped'));
    }

    @isTest
    static void testControlCleanup_STOP_NoPending() {
        delete [SELECT Id FROM SF_Async__c WHERE Task_Class_Name__c = 'AsyncCleanupTask' AND Executed__c = false];

        AsyncFramework_CleanupControl.ControlRequest req = new AsyncFramework_CleanupControl.ControlRequest();
        req.action = 'STOP';

        List<AsyncFramework_CleanupControl.FlowResult> results = AsyncFramework_CleanupControl.controlCleanup(new List<AsyncFramework_CleanupControl.ControlRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('No scheduled') || results[0].message.contains('progress'));
    }

    @isTest
    static void testControlCleanup_UnknownAction() {
        AsyncFramework_CleanupControl.ControlRequest req = new AsyncFramework_CleanupControl.ControlRequest();
        req.action = 'UNKNOWN';

        List<AsyncFramework_CleanupControl.FlowResult> results = AsyncFramework_CleanupControl.controlCleanup(new List<AsyncFramework_CleanupControl.ControlRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('Unknown'));
    }
}
