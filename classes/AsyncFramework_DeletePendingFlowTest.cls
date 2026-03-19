/***
* @description Test class for AsyncFramework_DeletePendingFlow invocable wrapper.
***/
@isTest
public with sharing class AsyncFramework_DeletePendingFlowTest {

    @isTest
    static void testInvoke_DeleteAll() {
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'TestTask',
            Scheduled_Time__c = System.now(),
            Executed__c = false,
            Before_Cancelling__c = 3
        );
        insert task;

        List<List<Boolean>> input = new List<List<Boolean>>{ new List<Boolean>{ true } };

        Test.startTest();
        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingFlow.invoke(input);
        Test.stopTest();

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].recordsDeleted >= 1);
    }

    @isTest
    static void testInvoke_Preserve() {
        List<List<Boolean>> input = new List<List<Boolean>>{ new List<Boolean>{ false } };

        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingFlow.invoke(input);
        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testInvoke_EmptyList() {
        List<List<Boolean>> input = new List<List<Boolean>>{ new List<Boolean>() };

        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingFlow.invoke(input);
        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testInvoke_NullElement() {
        List<List<Boolean>> input = new List<List<Boolean>>{ null };

        List<AsyncFramework_DeletePendingControl.FlowResult> results = AsyncFramework_DeletePendingFlow.invoke(input);
        Assert.isTrue(!results.isEmpty());
    }
}