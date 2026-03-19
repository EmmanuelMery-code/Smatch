/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Custom Iterator allowing iteration over SOQL aggregation query results.
*              Executes the query and maintains an index to iterate over results.
***/ 
public with sharing class AggregateResultIterator implements Iterator<AggregateResult> {
    private List<AggregateResult> results;
    private Integer index;
    
    /*** 
    * @description Constructor that executes the SOQL query and initializes the iteration index
    * @param query The SOQL aggregation query to execute
    * @return 
    * @Exception QueryException If the query is invalid or fails
    ***/ 
    public AggregateResultIterator(String query) {
        this.index = 0;
        try {
            this.results = Database.query(query);
        } catch (QueryException e) {
            // System.debug('Error executing SOQL query: ' + e.getMessage());
            this.results = new List<AggregateResult>();
            throw e;
        }
    }
    
    /*** 
    * @description Checks if there are remaining elements to iterate over in the results list
    * @param  
    * @return Boolean True if elements remain to iterate over, False otherwise
    * @Exception 
    ***/ 
    public boolean hasNext() { 
        return results != null && !results.isEmpty() && index < results.size(); 
    }
    
    /*** 
    * @description Returns the next element in the results list and increments the index
    * @param  
    * @return AggregateResult The next element in the results list
    * @Exception 
    ***/ 
    public AggregateResult next() { 
        return results[index++]; 
    }
}