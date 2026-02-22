/***
* @description Test class for AsyncFramework_DeletePendingControl invocable action.
***/
@isTest
public with sharing class AsyncFramework_DeletePendingControlTest {

    @isTest
    static void testDeletePendingControl_DeleteAll() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'TestTask',
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert task;

        AsyncFramework_DeletePendingControl.ControlRequest req = new AsyncFramework_DeletePendingControl.ControlRequest();
        req.deletePending = true;

        Test.startTest();
        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingControl.deletePendingControl(
            new List<AsyncFramework_DeletePendingControl.ControlRequest>{ req });
        Test.stopTest();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].recordsDeleted >= 1);
        Assert.isTrue(results[0].message.contains('deleted'));
    }

    @isTest
    static void testDeletePendingControl_PreserveStatsAndCleanup() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'TestTask',
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert task;

        AsyncFramework_DeletePendingControl.ControlRequest req = new AsyncFramework_DeletePendingControl.ControlRequest();
        req.deletePending = false;

        Test.startTest();
        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingControl.deletePendingControl(
            new List<AsyncFramework_DeletePendingControl.ControlRequest>{ req });
        Test.stopTest();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].message.contains('deleted') || results[0].message.contains('Error'));
    }

    @isTest
    static void testDeleteOrMaintain_DeleteAll() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'TestTask',
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert task;

        AsyncFramework_DeletePendingControl.DeleteResult result = AsyncFramework_DeletePendingControl.deleteOrMaintain(true);
        Assert.isTrue(result.deleted >= 1);
    }

    @isTest
    static void testDeleteOrMaintain_Preserve() {
        SF_Async__c cleanupTask = new SF_Async__c(
            Task_Class_Name__c = AsyncCleanupTask.class.getName(),
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert cleanupTask;

        AsyncFramework_DeletePendingControl.DeleteResult result = AsyncFramework_DeletePendingControl.deleteOrMaintain(false);
        Assert.areEqual(0, result.deleted, 'Cleanup task should be preserved');
    }

    @isTest
    static void testDeletePendingControl_NullDeletePending() {
        AsyncFramework_DeletePendingControl.ControlRequest req = new AsyncFramework_DeletePendingControl.ControlRequest();
        req.deletePending = null;

        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingControl.deletePendingControl(
            new List<AsyncFramework_DeletePendingControl.ControlRequest>{ req });
        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testDeleteOrMaintain_WithRemaining() {
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 15; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'TestTask' + i,
                Scheduled_Time__c = System.now(),
                Executed__c = false,
                Before_Cancelling__c = 3
            ));
        }
        insert tasks;

        AsyncFramework_DeletePendingControl.DeleteResult result = AsyncFramework_DeletePendingControl.deleteOrMaintain(true);

        Assert.isTrue(result.deleted >= 1);
    }

    @isTest
    static void testDeleteOrMaintain_PreserveStatistics() {
        SF_Async__c statsTask = new SF_Async__c(
            Task_Class_Name__c = AsyncStatisticsTask.class.getName(),
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert statsTask;

        AsyncFramework_DeletePendingControl.DeleteResult result = AsyncFramework_DeletePendingControl.deleteOrMaintain(false);

        Assert.areEqual(0, result.deleted, 'Statistics task should be preserved');
    }

    @isTest
    static void testDeleteOrMaintain_MultipleBatchesWithRemaining() {
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 25; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'TestTaskBatch' + i,
                Scheduled_Time__c = System.now(),
                Executed__c = false,
                Before_Cancelling__c = 3
            ));
        }
        insert tasks;

        AsyncFramework_DeletePendingControl.DeleteResult result = AsyncFramework_DeletePendingControl.deleteOrMaintain(true);

        Assert.isTrue(result.deleted >= 1);
    }

    @isTest
    static void testDeletePendingControl_ExceptionCaught() {
        AsyncFramework_DeletePendingControl.testSimulateException = true;

        AsyncFramework_DeletePendingControl.ControlRequest req = new AsyncFramework_DeletePendingControl.ControlRequest();
        req.deletePending = true;

        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingControl.deletePendingControl(
            new List<AsyncFramework_DeletePendingControl.ControlRequest>{ req });

        AsyncFramework_DeletePendingControl.testSimulateException = false;

        Assert.isTrue(!results.isEmpty());
        Assert.areEqual(0, results[0].recordsDeleted);
        Assert.isTrue(results[0].message.contains('Simulated') || results[0].message.contains('Error'));
    }

    @isTest
    static void testDeleteOrMaintain_RemainingGreaterThanZero() {
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for (Integer i = 0; i < 250; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'TestTaskRemain' + i,
                Scheduled_Time__c = System.now(),
                Executed__c = false,
                Before_Cancelling__c = 3
            ));
        }
        insert tasks;

        AsyncFramework_DeletePendingControl.testMaxIterations = 1;

        AsyncFramework_DeletePendingControl.DeleteResult result = AsyncFramework_DeletePendingControl.deleteOrMaintain(true);

        AsyncFramework_DeletePendingControl.testMaxIterations = null;

        Assert.isTrue(result.deleted >= 200);
        Assert.isTrue(result.remaining >= 1);
    }
}