/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Utility class to retrieve Async Framework configuration constants from Custom Metadata.
*              Uses getInstance() which does not consume SOQL queries. Provides default values
*              if Custom Metadata is not configured.
***/ 
public with sharing class AsyncFrameworkConfig {
    
    private static Async_Framework_Configuration__mdt config;
    
    /*** 
    * @description Clears the cached config. Call after metadata update so next read gets fresh values.
    ***/ 
    public static void clearConfig() {
        config = null;
    }
    
    private static Async_Framework_Configuration__mdt getConfig() {
        if (config == null) {
            try {
                config = Async_Framework_Configuration__mdt.getInstance('Default_Configuration');
            } catch (Exception e) {
                // System.debug('AsyncFrameworkConfig: Custom Metadata not found, using defaults. Error: ' + e.getMessage());
                return null;
            }
        }
        return config;
    }
    
    public static Integer getDmlSafeThreshold() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        Integer raw = cfg != null && cfg.DML_Safe_Threshold__c != null ? cfg.DML_Safe_Threshold__c.intValue() : 75;
        return Math.min(150, Math.max(1, raw));
    }
    
    public static Integer getSafeCpuLimit() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Safe_Cpu_Limit__c != null ? cfg.Safe_Cpu_Limit__c.intValue() : 45000;
    }
    
    public static Integer getMinBatchSize() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Min_Batch_Size__c != null ? cfg.Min_Batch_Size__c.intValue() : 1;
    }
    
    public static Integer getMaxNumberWorker() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Max_Number_Worker__c != null ? cfg.Max_Number_Worker__c.intValue() : 32;
    }

    public static Integer getParallelLowThreshold() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Parallel_Low_Threshold__c != null ? cfg.Parallel_Low_Threshold__c.intValue() : 200;
    }
    
    public static Integer getMaxBatchSize() {
        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        if (rtc != null && rtc.Max_Batch_Size_Override__c != null && rtc.Max_Batch_Size_Override__c >= 1) {
            return rtc.Max_Batch_Size_Override__c.intValue();
        }
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Max_Batch_Size__c != null ? cfg.Max_Batch_Size__c.intValue() : 200;
    }

    public static Integer getTasksPerWorkerDefault() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Tasks_Per_Worker_Default__c != null ? cfg.Tasks_Per_Worker_Default__c.intValue() : 200;
    }

    public static void setMaxBatchSizeOverride(Integer newSize) {
        if (newSize == null || newSize < 1) return;
        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        if (rtc == null) rtc = new Async_Runtime_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        rtc.Max_Batch_Size_Override__c = newSize;
        upsert rtc;
    }

    public static void clearMaxBatchSizeOverride() {
        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        if (rtc == null) rtc = new Async_Runtime_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        if (rtc.Max_Batch_Size_Override__c != null || rtc.Active_Worker_Count__c != null) {
            rtc.Max_Batch_Size_Override__c = null;
            rtc.Active_Worker_Count__c = 1;
            upsert rtc;
        }
    }

    public static Integer getActiveWorkerCount() {
        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        return (rtc != null && rtc.Active_Worker_Count__c != null && rtc.Active_Worker_Count__c >= 1)
            ? rtc.Active_Worker_Count__c.intValue() : null;
    }

    public static void setActiveWorkerCount(Integer count) {
        if (count == null || count < 1) return;
        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        if (rtc == null) rtc = new Async_Runtime_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        rtc.Active_Worker_Count__c = count;
        upsert rtc;
    }
    
    public static Integer getDefaultCpuCostMs() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Default_CPU_Cost_ms__c != null ? cfg.Default_CPU_Cost_ms__c.intValue() : 1000;
    }
    
    public static Integer getCpuReserveMs() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.CPU_Reserve_ms__c != null ? cfg.CPU_Reserve_ms__c.intValue() : 2000;
    }
    
    public static Integer getDaysToAnalyze() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Days_To_Analyze__c != null ? cfg.Days_To_Analyze__c.intValue() : 7;
    }
    
    public static String getStatusSuccess() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Status_Success__c != null ? cfg.Status_Success__c : 'Success';
    }
    
    public static Decimal getSafetyMarginMultiplier() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Safety_Margin_Multiplier__c != null ? cfg.Safety_Margin_Multiplier__c : 1.2;
    }
    
    public static Integer getDaysToKeep() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Days_To_Keep__c != null ? cfg.Days_To_Keep__c.intValue() : 30;
    }
    
    public static Integer getCleanupCpuReserveMs() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Cleanup_CPU_Reserve_ms__c != null ? cfg.Cleanup_CPU_Reserve_ms__c.intValue() : 5000;
    }
    
    public static Integer getCleanupBatchSize() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Cleanup_Batch_Size__c != null ? cfg.Cleanup_Batch_Size__c.intValue() : 2000;
    }
    
    public static Integer getBeforeCancelling() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Before_Cancelling__c != null ? cfg.Before_Cancelling__c.intValue() : 3;
    }
    
    public static Integer getExecutionOrder() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Execution_Order__c != null ? cfg.Execution_Order__c.intValue() : 99;
    }
    
    public static Integer getDefaultSchedulerFrequencyMinutes() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        return cfg != null && cfg.Scheduler_Frequency_Minutes__c != null
            ? cfg.Scheduler_Frequency_Minutes__c.intValue() : 1;
    }
    
    public static Integer getDeletePendingMaxIterations() {
        Async_Framework_Configuration__mdt cfg = getConfig();
        Integer raw = cfg != null && cfg.Delete_Pending_Max_Iterations__c != null ? cfg.Delete_Pending_Max_Iterations__c.intValue() : 10;
        return Math.min(100, Math.max(1, raw));
    }
}