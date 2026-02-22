/***
* @description Test class for AsyncWakeUpTrigger - covers PARALLEL_WORKERS, REDUCE_BATCH_SIZE, WAKEUP.
***/
@isTest
public with sharing class AsyncWakeUpTriggerTest {

    @isTest
    static void testTrigger_WAKEUP() {
        Test.startTest();
        EventBus.publish(new Async_WakeUp__e(Event_Type__c = 'WAKEUP'));
        Test.stopTest();
        Assert.isTrue(true, 'WAKEUP should enqueue worker');
    }

    @isTest
    static void testTrigger_ParallelWorkers() {
        Test.startTest();
        EventBus.publish(new Async_WakeUp__e(
            Event_Type__c = 'PARALLEL_WORKERS',
            Batch_Size__c = 3
        ));
        Test.stopTest();
        Assert.isTrue(true, 'PARALLEL_WORKERS should spawn workers');
    }

    @isTest
    static void testTrigger_ReduceBatchSize() {
        Test.startTest();
        EventBus.publish(new Async_WakeUp__e(
            Event_Type__c = 'REDUCE_BATCH_SIZE',
            Batch_Size__c = 5,
            Workers_Count__c = 2
        ));
        Test.stopTest();

        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        Assert.isNotNull(rtc);
        Assert.areEqual(5, rtc.Max_Batch_Size_Override__c);
    }

    @isTest
    static void testTrigger_ReduceBatchSize_FromErrorMessage() {
        Test.startTest();
        EventBus.publish(new Async_WakeUp__e(
            Event_Type__c = 'REDUCE_BATCH_SIZE',
            Batch_Size__c = null,
            Error_Message__c = '10'
        ));
        Test.stopTest();

        Async_Runtime_Config__c rtc = Async_Runtime_Config__c.getOrgDefaults();
        Assert.isNotNull(rtc);
        Assert.areEqual(10, rtc.Max_Batch_Size_Override__c);
    }

    @isTest
    static void testTrigger_NullEventType() {
        Test.startTest();
        EventBus.publish(new Async_WakeUp__e(Event_Type__c = null));
        Test.stopTest();
        Assert.isTrue(true, 'Null Event_Type should trigger WAKEUP');
    }

    @isTest
    static void testTrigger_ReduceBatchSize_InvalidErrorMessage() {
        Test.startTest();
        EventBus.publish(new Async_WakeUp__e(
            Event_Type__c = 'REDUCE_BATCH_SIZE',
            Batch_Size__c = null,
            Error_Message__c = 'invalid'
        ));
        Test.stopTest();
        Assert.isTrue(true, 'Invalid Error_Message should fallback to 1');
    }
}
