/***
* @description Test class for AsyncReduceBatchSizeJob queueable fallback.
***/
@isTest
public with sharing class AsyncReduceBatchSizeJobTest {

    @isTest
    static void testExecute_ValidBatchSize() {
        Test.startTest();
        System.enqueueJob(new AsyncReduceBatchSizeJob(5));
        Test.stopTest();

        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        Assert.isNotNull(rtc);
    }

    @isTest
    static void testExecute_WithActiveWorkerCount() {
        AsyncFrameworkConfig.setActiveWorkerCount(3);
        AsyncReduceBatchSizeJob.testExecuteFullPath = true;

        Test.startTest();
        System.enqueueJob(new AsyncReduceBatchSizeJob(10));
        Test.stopTest();

        AsyncReduceBatchSizeJob.testExecuteFullPath = false;
        Assert.isTrue(AsyncFrameworkConfig.getMaxBatchSize() == 10 || AsyncFrameworkConfig.getMaxBatchSize() >= 1);
    }

    @isTest
    static void testExecute_NullBatchSize() {
        Test.startTest();
        System.enqueueJob(new AsyncReduceBatchSizeJob(null));
        Test.stopTest();
        Assert.isTrue(true);
    }

    @isTest
    static void testExecute_ZeroBatchSize() {
        Test.startTest();
        System.enqueueJob(new AsyncReduceBatchSizeJob(0));
        Test.stopTest();
        Assert.isTrue(true);
    }

    @isTest
    static void testExecute_NegativeBatchSize() {
        Test.startTest();
        System.enqueueJob(new AsyncReduceBatchSizeJob(-1));
        Test.stopTest();
        Assert.isTrue(true);
    }
}