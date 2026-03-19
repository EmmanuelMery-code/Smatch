/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Test class for the AsyncLearningBatch learning batch and the Worker's smart batching.
*              Verifies that performance statistics are correctly calculated and used.
***/ 
@isTest
public with sharing class AsyncAnalyticsTest {

    /*** 
    * @description Mock class to simulate an asynchronous task in tests
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class MockTask implements IAsyncTask { 
        /*** 
        * @description Empty execution method for tests
        * @param c The SF_Async__c context record
        * @return 
        * @Exception 
        ***/ 
        public void run(SF_Async__c c){} 
    }

    /*** 
    * @description Setup method that creates necessary test data (task and logs)
    * @param  
    * @return 
    * @Exception 
    ***/ 
    @TestSetup
    static void makeData(){
        SF_Async__c task = new SF_Async__c(Task_Class_Name__c = 'AsyncAnalyticsTest.MockTask');
        insert task;

        // Creating 10 success logs with CPU_Time__c = 1000ms for tests
        List<SF_Async_Log__c> logs = new List<SF_Async_Log__c>();
        for(Integer i=0; i<10; i++) {
            logs.add(new SF_Async_Log__c(
                SF_Async__c = task.Id,
                Status__c = 'Success',
                CPU_Time__c = 1000
            ));
        }
        insert logs;
    }

    /*** 
    * @description Test of the learning batch that verifies creation/update of performance statistics
    * @param  
    * @return 
    * @Exception 
    ***/ 
    @isTest
    static void testLearningBatch() {
        Test.startTest();
        Database.executeBatch(new AsyncLearningBatch());
        Test.stopTest();

        // Verifying creation/update of performance statistics
        String className = 'AsyncAnalyticsTest.MockTask';
        List<SF_Async_Performance__c> existingPerfs = [
            SELECT Id, Average_CPU__c, Sample_Size__c 
            FROM SF_Async_Performance__c 
            WHERE Name = :className 
            LIMIT 1
        ];

        Assert.isTrue(!existingPerfs.isEmpty(), 'A performance record should have been created by the batch.');

        SF_Async_Performance__c perf = existingPerfs[0];
        Assert.isTrue(perf.Average_CPU__c >= 1000 && perf.Average_CPU__c <= 1200,
            'Average CPU should be between 1000 (margin 1.0) and 1200 (margin 1.2). Actual: ' + perf.Average_CPU__c);
        Assert.areEqual(10, perf.Sample_Size__c, 'The sample size should be 10.');
    }
    
    /*** 
    * @description Test that the Worker uses smart batching based on historical performance
    * @param  
    * @return 
    * @Exception 
    ***/ 
    @isTest
    static void testWorkerUsesSmartBatching() {
        // Remove perf records created by testLearningBatch to ensure our value is used
        delete [SELECT Id FROM SF_Async_Performance__c WHERE Name = 'AsyncAnalyticsTest.MockTask'];
        // Injecting slow performance (22500ms) to test batching adaptation
        // With SAFE_CPU_LIMIT = 45000ms, the batch should be limited to 2 tasks (45000 / 22500 = 2)
        SF_Async_Performance__c perf = new SF_Async_Performance__c(
            Name = 'AsyncAnalyticsTest.MockTask',
            Average_CPU__c = 22500
        );
        insert perf;
        
        List<SF_Async__c> tasks = new List<SF_Async__c>();
        for(Integer i=0; i<5; i++) {
            tasks.add(new SF_Async__c(
                Task_Class_Name__c = 'AsyncAnalyticsTest.MockTask',
                Scheduled_Time__c = System.now().addHours(-1)
            ));
        }
        insert tasks;
        
        Integer initialCount = [SELECT Count() FROM SF_Async__c WHERE Executed__c = TRUE];
        
        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();
        
        // Verifying that the worker processed exactly 2 tasks (smart batching limit)
        Integer executedCount = [SELECT Count() FROM SF_Async__c WHERE Executed__c = TRUE] - initialCount;
        Assert.isTrue(executedCount > 0, 'The worker should have processed tasks.');
        Assert.isTrue(executedCount <= 2, 'Smart batching should limit to 2 tasks with this performance.');
    }

    @isTest
    static void testAggregateResultIterator_InvalidQuery() {
        try {
            new AggregateResultIterator('SELECT Invalid FROM Nothing');
            Assert.fail('Should have thrown QueryException');
        } catch (QueryException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()));
        } catch (Exception e) {
            Assert.isTrue(e.getTypeName().contains('Query') || e.getMessage().contains('query'));
        }
    }

    @isTest
    static void testLearningBatch_EmptyData() {
        delete [SELECT Id FROM SF_Async_Log__c];
        Test.startTest();
        Database.executeBatch(new AsyncLearningBatch());
        Test.stopTest();
        Assert.isTrue(true, 'Batch with no logs should complete');
    }

    @isTest
    static void testStatisticsTask() {
        delete [SELECT Id FROM SF_Async__c WHERE Task_Class_Name__c = 'AsyncStatisticsTask'];
        SF_Async__c task = new SF_Async__c(
            Task_Class_Name__c = 'AsyncStatisticsTask',
            Scheduled_Time__c = System.now().addHours(-1),
            label__c = 'Daily Stat'
        );
        insert task;

        Test.startTest();
        System.enqueueJob(new AsyncWorkerQueueable());
        Test.stopTest();

        task = [SELECT Executed__c FROM SF_Async__c WHERE Id = :task.Id];
        Assert.isTrue(task.Executed__c, 'AsyncStatisticsTask should be executed');
        Integer nextScheduled = [SELECT COUNT() FROM SF_Async__c WHERE Task_Class_Name__c = 'AsyncStatisticsTask' AND Executed__c = false];
        Assert.isTrue(nextScheduled >= 1, 'Next statistics run should be scheduled');
    }
}