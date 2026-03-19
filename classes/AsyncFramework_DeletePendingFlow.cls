/*** 
* @author Emmanuel (EMM) 
* @date 15/02/2026 
* @description Flow-friendly invocable wrapper for delete pending. Accepts List of Boolean (e.g. one element) for easy Flow input.
***/ 
public with sharing class AsyncFramework_DeletePendingFlow {
    
    @InvocableMethod(
        label='Delete pending (Flow)'
        description='Delete pending SF_Async__c. deleteAllCollection: [true]=delete all, [false]=preserve AsyncCleanupTask and AsyncStatisticsTask.'
        category='Async Framework'
    )
    public static List<AsyncFramework_DeletePendingControl.FlowResult> invoke(List<List<Boolean>> deleteAllCollection) {
        List<AsyncFramework_DeletePendingControl.ControlRequest> requests = new List<AsyncFramework_DeletePendingControl.ControlRequest>();
        for (List<Boolean> bulkItem : deleteAllCollection) {
            Boolean deleteAll = (bulkItem != null && !bulkItem.isEmpty()) ? bulkItem[0] : false;
            AsyncFramework_DeletePendingControl.ControlRequest cr = new AsyncFramework_DeletePendingControl.ControlRequest();
            cr.deletePending = deleteAll;
            requests.add(cr);
        }
        return AsyncFramework_DeletePendingControl.deletePendingControl(requests);
    }
}