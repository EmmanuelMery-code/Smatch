/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Batch that analyzes historical performance of asynchronous tasks over the last 7 days
*              and updates performance statistics to optimize the Worker's smart batching.
***/ 
public with sharing class AsyncLearningBatch implements Database.Batchable<AggregateResult> {

    // Configuration constants are now retrieved from Custom Metadata via AsyncFrameworkConfig
    // This allows configuration changes without code deployment and does not consume SOQL queries

    /*** 
    * @description Starts the batch by preparing the aggregation query on performance logs
    * @param BC The Batchable context provided by Salesforce
    * @return Iterable<AggregateResult> An iterable containing aggregation results by task class
    * @Exception 
    ***/ 
    public Iterable<AggregateResult> start(Database.BatchableContext BC) {
        // Secure the query: validate and cap inputs to prevent SOQL injection and excessive scope
        Integer days = AsyncFrameworkConfig.getDaysToAnalyze();
        days = (days == null || days < 1) ? 7 : Math.min(365, days);

        String status = AsyncFrameworkConfig.getStatusSuccess();
        if (String.isBlank(status) || status.length() > 50) {
            status = 'Success';
        }
        status = String.escapeSingleQuotes(status);

        String query = 'SELECT SF_Async__r.Task_Class_Name__c className, AVG(CPU_Time__c) avgCpu, COUNT(Id) sampleSize ' +
                       'FROM SF_Async_Log__c ' +
                       'WHERE CreatedDate = LAST_N_DAYS:' + days +
                       ' AND Status__c = \'' + status + '\' ' +
                       'GROUP BY SF_Async__r.Task_Class_Name__c';
        return new AggregateResultIterable(query);
    }

    /*** 
    * @description Processes aggregation results and updates performance statistics
    * @param BC The Batchable context provided by Salesforce
    * @param scope The list of aggregation results to process
    * @return 
    * @Exception 
    ***/ 
    public void execute(Database.BatchableContext BC, List<AggregateResult> scope) {
        // Collecting class names from aggregation results
        Set<String> classNames = new Set<String>();
        for (AggregateResult ar : scope) {
            String name = (String) ar.get('className');
            if (String.isNotBlank(name)) {
                classNames.add(name);
            }
        }

        // Retrieving existing performances in bulk
        Map<String, SF_Async_Performance__c> existingPerfsMap = new Map<String, SF_Async_Performance__c>();
        
        if (!classNames.isEmpty()) {
            List<SF_Async_Performance__c> foundPerfs = [
                SELECT Id, Name, Average_CPU__c, Sample_Size__c 
                FROM SF_Async_Performance__c 
                WHERE Name IN :classNames
            ];
            for (SF_Async_Performance__c p : foundPerfs) {
                existingPerfsMap.put(p.Name, p);
            }
        }

        // Processing and updating statistics
        List<SF_Async_Performance__c> perfsToUpsert = new List<SF_Async_Performance__c>();

        for (AggregateResult ar : scope) {
            String className = (String) ar.get('className');
            
            if (String.isBlank(className)) continue; 

            Decimal avgCpu = (Decimal) ar.get('avgCpu');
            Integer count = (Integer) ar.get('sampleSize');
            
            // Applying a safety margin to avoid CPU overruns
            Decimal safeAvgCpu = (avgCpu != null ? avgCpu * AsyncFrameworkConfig.getSafetyMarginMultiplier() : 0);

            SF_Async_Performance__c perf;
            
            if (existingPerfsMap.containsKey(className)) {
                perf = existingPerfsMap.get(className);
            } else {
                perf = new SF_Async_Performance__c(Name = className);
            }

            perf.Average_CPU__c = safeAvgCpu;
            perf.Sample_Size__c = count;
            
            perfsToUpsert.add(perf);
        }

        // Saving with partial error handling
        if (!perfsToUpsert.isEmpty()) {
            Database.upsert(perfsToUpsert, false);
        }
    }

    /*** 
    * @description Method called at the end of the batch (not used in this implementation)
    * @param BC The Batchable context provided by Salesforce
    * @return 
    * @Exception 
    ***/ 
    public void finish(Database.BatchableContext BC) {}
}