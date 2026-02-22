/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Iterable wrapper that allows iteration over SOQL aggregation query results.
*              Delegates iteration to AggregateResultIterator.
***/ 
public with sharing class AggregateResultIterable implements Iterable<AggregateResult> {
    private String query;
    
    /*** 
    * @description Constructor that stores the SOQL query for deferred execution by the iterator
    * @param query The SOQL aggregation query to execute
    * @return 
    * @Exception 
    ***/ 
    public AggregateResultIterable(String query) { this.query = query; }
    
    /*** 
    * @description Returns a new AggregateResultIterator for the stored query
    * @param  
    * @return Iterator<AggregateResult> Iterator over the query results
    * @Exception 
    ***/ 
    public Iterator<AggregateResult> iterator() { return new AggregateResultIterator(this.query); }
}