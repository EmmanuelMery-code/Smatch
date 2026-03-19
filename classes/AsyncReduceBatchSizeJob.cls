/***
* @description Queueable fallback when EventBus.publish fails (e.g. over DML limit).
*              Updates Custom Setting and publishes REDUCE_BATCH_SIZE in a fresh transaction.
***/
public with sharing class AsyncReduceBatchSizeJob implements Queueable {
    @TestVisible private static Boolean testExecuteFullPath = false;
    private final Integer newBatchSize;

    public AsyncReduceBatchSizeJob(Integer newBatchSize) {
        this.newBatchSize = newBatchSize;
    }

    public void execute(QueueableContext context) {
        if (newBatchSize == null || newBatchSize < 1) return;
        try {
            AsyncFrameworkConfig.setMaxBatchSizeOverride(newBatchSize);
            Integer workersCount = 1;
            if (!Test.isRunningTest() || testExecuteFullPath) {
                Integer queryCount = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable' AND ApexClass.Name = 'AsyncWorkerQueueable' AND Status IN ('Queued', 'Preparing', 'Processing')];
                Integer storedCount = AsyncFrameworkConfig.getActiveWorkerCount();
                workersCount = (storedCount != null && storedCount > queryCount) ? storedCount : Math.max(1, queryCount);
            }
            EventBus.publish(new Async_WakeUp__e(
                Event_Type__c = 'REDUCE_BATCH_SIZE',
                Batch_Size__c = newBatchSize,
                Workers_Count__c = workersCount,
                Error_Message__c = String.valueOf(newBatchSize)
            ));
            // System.debug('AsyncReduceBatchSizeJob: Override set to ' + newBatchSize + ', workers=' + workersCount + ', event published.');
        } catch (Exception e) {
            // System.debug('AsyncReduceBatchSizeJob: Failed. ' + e.getMessage());
        }
    }
}