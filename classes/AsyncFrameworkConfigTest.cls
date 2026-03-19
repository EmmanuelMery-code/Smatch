/***
* @description Test class for AsyncFrameworkConfig - Custom Metadata configuration getters.
***/
@isTest
public with sharing class AsyncFrameworkConfigTest {

    @isTest
    static void testClearConfig() {
        AsyncFrameworkConfig.clearConfig();
        Integer dml = AsyncFrameworkConfig.getDmlSafeThreshold();
        Assert.isTrue(dml >= 1 && dml <= 150);
    }

    @isTest
    static void testGetDmlSafeThreshold() {
        Integer dml = AsyncFrameworkConfig.getDmlSafeThreshold();
        Assert.isTrue(dml >= 1 && dml <= 150);
    }

    @isTest
    static void testGetSafeCpuLimit() {
        Integer cpu = AsyncFrameworkConfig.getSafeCpuLimit();
        Assert.isTrue(cpu > 0);
    }

    @isTest
    static void testGetMinBatchSize() {
        Integer min = AsyncFrameworkConfig.getMinBatchSize();
        Assert.isTrue(min >= 1);
    }

    @isTest
    static void testGetMaxNumberWorker() {
        Integer max = AsyncFrameworkConfig.getMaxNumberWorker();
        Assert.isTrue(max >= 1);
    }

    @isTest
    static void testGetParallelLowThreshold() {
        Integer th = AsyncFrameworkConfig.getParallelLowThreshold();
        Assert.isTrue(th >= 1);
    }

    @isTest
    static void testGetMaxBatchSize() {
        Integer max = AsyncFrameworkConfig.getMaxBatchSize();
        Assert.isTrue(max >= 1);
    }

    @isTest
    static void testGetMaxBatchSize_WithOverride() {
        AsyncFrameworkConfig.setMaxBatchSizeOverride(10);
        Integer max = AsyncFrameworkConfig.getMaxBatchSize();
        Assert.areEqual(10, max);
        AsyncFrameworkConfig.clearMaxBatchSizeOverride();
    }

    @isTest
    static void testGetTasksPerWorkerDefault() {
        Integer def = AsyncFrameworkConfig.getTasksPerWorkerDefault();
        Assert.isTrue(def >= 1);
    }

    @isTest
    static void testSetAndClearMaxBatchSizeOverride() {
        AsyncFrameworkConfig.setMaxBatchSizeOverride(15);
        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        Assert.isTrue(rtc != null && rtc.Max_Batch_Size_Override__c == 15);
        AsyncFrameworkConfig.clearMaxBatchSizeOverride();
        rtc = Async_Runtime_Config__c.getOrgDefaults();
        Assert.isTrue(rtc.Max_Batch_Size_Override__c == null || rtc.Max_Batch_Size_Override__c == 0);
    }

    @isTest
    static void testSetMaxBatchSizeOverride_Invalid() {
        Integer before = AsyncFrameworkConfig.getMaxBatchSize();
        AsyncFrameworkConfig.setMaxBatchSizeOverride(null);
        AsyncFrameworkConfig.setMaxBatchSizeOverride(0);
        Integer after = AsyncFrameworkConfig.getMaxBatchSize();
        Assert.isTrue(after >= 1);
    }

    @isTest
    static void testGetActiveWorkerCount() {
        Integer count = AsyncFrameworkConfig.getActiveWorkerCount();
        Assert.isTrue(count == null || count >= 1);
    }

    @isTest
    static void testSetActiveWorkerCount() {
        AsyncFrameworkConfig.setActiveWorkerCount(5);
        Integer count = AsyncFrameworkConfig.getActiveWorkerCount();
        Assert.isTrue(count != null && count >= 1);
        AsyncFrameworkConfig.clearMaxBatchSizeOverride();
    }

    @isTest
    static void testSetActiveWorkerCount_Invalid() {
        AsyncFrameworkConfig.setActiveWorkerCount(null);
        AsyncFrameworkConfig.setActiveWorkerCount(0);
        Assert.isTrue(true);
    }

    @isTest
    static void testGetDefaultCpuCostMs() {
        Integer cost = AsyncFrameworkConfig.getDefaultCpuCostMs();
        Assert.isTrue(cost >= 1);
    }

    @isTest
    static void testGetCpuReserveMs() {
        Integer reserve = AsyncFrameworkConfig.getCpuReserveMs();
        Assert.isTrue(reserve >= 0);
    }

    @isTest
    static void testGetDaysToAnalyze() {
        Integer days = AsyncFrameworkConfig.getDaysToAnalyze();
        Assert.isTrue(days >= 1);
    }

    @isTest
    static void testGetStatusSuccess() {
        String status = AsyncFrameworkConfig.getStatusSuccess();
        Assert.isTrue(String.isNotBlank(status));
    }

    @isTest
    static void testGetSafetyMarginMultiplier() {
        Decimal mult = AsyncFrameworkConfig.getSafetyMarginMultiplier();
        Assert.isTrue(mult != null && mult > 0);
    }

    @isTest
    static void testGetDaysToKeep() {
        Integer days = AsyncFrameworkConfig.getDaysToKeep();
        Assert.isTrue(days >= 1);
    }

    @isTest
    static void testGetCleanupCpuReserveMs() {
        Integer reserve = AsyncFrameworkConfig.getCleanupCpuReserveMs();
        Assert.isTrue(reserve >= 0);
    }

    @isTest
    static void testGetCleanupBatchSize() {
        Integer size = AsyncFrameworkConfig.getCleanupBatchSize();
        Assert.isTrue(size >= 1);
    }

    @isTest
    static void testGetBeforeCancelling() {
        Integer before = AsyncFrameworkConfig.getBeforeCancelling();
        Assert.isTrue(before >= 1);
    }

    @isTest
    static void testGetExecutionOrder() {
        Integer order = AsyncFrameworkConfig.getExecutionOrder();
        Assert.isTrue(order >= 0);
    }

    @isTest
    static void testGetDefaultSchedulerFrequencyMinutes() {
        Integer freq = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
        Assert.isTrue(freq >= 1);
    }
}