/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Invocable class for Screen Flows that retrieves execution frequency and next execution time
*              for async tasks. Analyzes SF_Async__c records to determine scheduling patterns.
***/ 
public with sharing class AsyncTaskScheduleInfo {
    
    /*** 
    * @description Input wrapper for Flow invocable method
    ***/ 
    public class ScheduleRequest {
        @InvocableVariable(label='Task Class Name' description='Fully qualified class name of the task' required=true)
        public String taskClassName;
        
        @InvocableVariable(label='Lookback Days' description='Number of days to analyze for frequency calculation (default: 7)')
        public Integer lookbackDays;
    }
    
    /*** 
    * @description Output wrapper for Flow invocable method
    ***/ 
    public class ScheduleResponse {
        @InvocableVariable(label='Task Class Name')
        public String taskClassName;
        
        @InvocableVariable(label='Execution Frequency (minutes)')
        public Decimal executionFrequencyMinutes;
        
        @InvocableVariable(label='Next Execution Date/Time')
        public Datetime nextExecutionDateTime;
        
        @InvocableVariable(label='Has Scheduled Tasks')
        public Boolean hasScheduledTasks;
        
        @InvocableVariable(label='Total Scheduled Tasks')
        public Integer totalScheduledTasks;
        
        @InvocableVariable(label='Message')
        public String message;
    }
    
    /*** 
    * @description Invocable method for Screen Flows. Retrieves execution frequency and next execution time
    *              for a given task class name.
    * @param requests List of ScheduleRequest containing task class name and optional lookback days
    * @return List<ScheduleResponse> List of schedule information for each requested task class
    * @Exception 
    ***/ 
    @InvocableMethod(label='Get Async Task Schedule Info' description='Gets execution frequency and next execution time for async tasks' category='Async Framework')
    public static List<ScheduleResponse> getScheduleInfo(List<ScheduleRequest> requests) {
        List<ScheduleResponse> responses = new List<ScheduleResponse>();
        
        for (ScheduleRequest request : requests) {
            ScheduleResponse response = new ScheduleResponse();
            response.taskClassName = request.taskClassName;
            
            if (String.isBlank(request.taskClassName)) {
                response.message = 'Task class name is required';
                response.hasScheduledTasks = false;
                responses.add(response);
                continue;
            }
            
            Integer lookbackDays = request.lookbackDays != null && request.lookbackDays > 0 
                ? request.lookbackDays 
                : 7;
            
            try {
                // Get scheduled tasks for this class
                List<SF_Async__c> scheduledTasks = [
                    SELECT Id, Scheduled_Time__c, Executed__c, Cancelled__c
                    FROM SF_Async__c
                    WHERE Task_Class_Name__c = :request.taskClassName
                    AND Executed__c = FALSE
                    AND Cancelled__c = FALSE
                    ORDER BY Scheduled_Time__c ASC
                ];
                
                response.totalScheduledTasks = scheduledTasks.size();
                response.hasScheduledTasks = !scheduledTasks.isEmpty();
                
                // Get next execution time (earliest scheduled task)
                if (!scheduledTasks.isEmpty()) {
                    response.nextExecutionDateTime = scheduledTasks[0].Scheduled_Time__c;
                }
                
                // Calculate execution frequency from historical executed tasks
                List<SF_Async__c> executedTasks = [
                    SELECT Scheduled_Time__c, Executed__c
                    FROM SF_Async__c
                    WHERE Task_Class_Name__c = :request.taskClassName
                    AND Executed__c = TRUE
                    AND Scheduled_Time__c >= :Datetime.now().addDays(-lookbackDays)
                    ORDER BY Scheduled_Time__c ASC
                ];
                
                if (executedTasks.size() >= 2) {
                    // Calculate average interval between executions
                    Decimal totalMinutes = 0;
                    Integer intervals = 0;
                    
                    for (Integer i = 1; i < executedTasks.size(); i++) {
                        Long diffMs = executedTasks[i].Scheduled_Time__c.getTime() - executedTasks[i-1].Scheduled_Time__c.getTime();
                        Decimal diffMinutes = Decimal.valueOf(diffMs) / (1000 * 60);
                        totalMinutes += diffMinutes;
                        intervals++;
                    }
                    
                    if (intervals > 0) {
                        response.executionFrequencyMinutes = totalMinutes / intervals;
                    }
                } else if (executedTasks.size() == 1 && !scheduledTasks.isEmpty()) {
                    // If only one execution, calculate from scheduled time to executed time
                    Long diffMs = executedTasks[0].Scheduled_Time__c.getTime() - System.now().getTime();
                    response.executionFrequencyMinutes = Decimal.valueOf(diffMs) / (1000 * 60);
                } else if (!scheduledTasks.isEmpty() && scheduledTasks.size() >= 2) {
                    // Calculate frequency from scheduled tasks
                    Decimal totalMinutes = 0;
                    Integer intervals = 0;
                    
                    for (Integer i = 1; i < scheduledTasks.size(); i++) {
                        Long diffMs = scheduledTasks[i].Scheduled_Time__c.getTime() - scheduledTasks[i-1].Scheduled_Time__c.getTime();
                        Decimal diffMinutes = Decimal.valueOf(diffMs) / (1000 * 60);
                        totalMinutes += diffMinutes;
                        intervals++;
                    }
                    
                    if (intervals > 0) {
                        response.executionFrequencyMinutes = totalMinutes / intervals;
                    }
                }
                
                if (response.executionFrequencyMinutes == null) {
                    response.message = 'Insufficient data to calculate frequency. Need at least 2 executions or scheduled tasks.';
                } else {
                    response.message = 'Frequency calculated successfully';
                }
                
            } catch (Exception e) {
                response.message = 'Error: ' + e.getMessage();
                response.hasScheduledTasks = false;
            }
            
            responses.add(response);
        }
        
        return responses;
    }
}