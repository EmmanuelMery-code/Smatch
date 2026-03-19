/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Interface that defines the contract for asynchronous tasks. All tasks must implement
*              the run method that receives an SF_Async__c context record.
***/ 
public interface IAsyncTask {
    /*** 
    * @description Executes the asynchronous task with the given context record.
    * @param contextRecord The SF_Async__c record containing task parameters and target information
    * @return 
    * @Exception 
    ***/ 
    void run(SF_Async__c contextRecord); 
}