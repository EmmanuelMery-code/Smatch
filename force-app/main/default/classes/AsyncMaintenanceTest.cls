/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Test class for the AsyncCleanupTask cleanup task. Verifies deletion of old records
*              and automatic rescheduling of the cleanup task.
***/ 
@isTest
public with sharing class AsyncMaintenanceTest {

    @isTest
    static void testCleanupTask() {
        // 1. Create "old" data
        // Tip: We cannot write CreatedDate directly.
        // However, the AsyncCleanupTask class uses "CreatedDate < :limitDate".
        // To test, we will temporarily modify the query in the Apex class
        // OR (cleaner) use Test.setCreatedDate() if available, 
        // otherwise we will test that the task executes without error and reschedules.
        
        SF_Async__c oldTask = new SF_Async__c(
            Task_Class_Name__c = 'OldTask', 
            Executed__c = true
        );
        insert oldTask;
        
        // Hack to simulate an old date (works in some test contexts)
        Test.setCreatedDate(oldTask.Id, System.now().addDays(-40));
        
        // 2. Prepare the cleanup task context
        AsyncCleanupTask cleanup = new AsyncCleanupTask();
        SF_Async__c context = new SF_Async__c(); // Empty context is sufficient

        Test.startTest();
        cleanup.run(context);
        Test.stopTest();

        // 3. Verifications
        
        // A. Deletion
        List<SF_Async__c> checkOld = [SELECT Id FROM SF_Async__c WHERE Id = :oldTask.Id];
        Assert.areEqual(0, checkOld.size(), 'The old task should have been deleted.');

        // B. Rescheduling
        List<SF_Async__c> nextRun = [SELECT Id, Task_Class_Name__c, Scheduled_Time__c FROM SF_Async__c WHERE Task_Class_Name__c = 'AsyncCleanupTask'];
        Assert.isTrue(nextRun.size() > 0, 'A new cleanup task must be scheduled.');

        // Verify it's for tomorrow (approximately)
        Long diff = nextRun[0].Scheduled_Time__c.getTime() - System.now().getTime();
        Assert.isTrue(diff > 80000000, 'The next task must be in the future (24h).');
    }
}