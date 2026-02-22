/*** 
* @author Emmanuel (EMM) 
* @date 09/02/2026 
* @description Invocable class for Screen Flows to manage AsyncScheduler scheduling.
*              Shows existing schedules for Worker and Watchdog. Supports frequency in minutes.
***/ 
public with sharing class AsyncSchedulerSetup {
    
    private static final String DEFAULT_JOB_NAME = 'Async Framework Scheduler';
    
    /*** 
    * @description Input wrapper for getting schedule information
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class GetScheduleRequest {
        @InvocableVariable(label='Action' description='Action to perform: GET_INFO, SCHEDULE_EVERY_MINUTE, SCHEDULE_CUSTOM' required=true)
        public String action;
        
        @InvocableVariable(label='Frequency (minutes)' description='Frequency in minutes for SCHEDULE_CUSTOM. Default: 1 (from AsyncFrameworkConfig)')
        public Integer frequencyMinutes;
        
        @InvocableVariable(label='Job Name' description='Name for the scheduled job')
        public String jobName;
        
        @InvocableVariable(label='Use Single Scheduler' description='If true: 1 self-rescheduling job. If false: N cron jobs (one per slot).')
        public Boolean useSingleScheduler;
    }
    
    /*** 
    * @description Output wrapper for schedule information
    * @param  
    * @return 
    * @Exception 
    ***/ 
    public class ScheduleInfoResponse {
        @InvocableVariable(label='Has Scheduler Job')
        public Boolean hasSchedulerJob;
        
        @InvocableVariable(label='Scheduler Job ID')
        public String schedulerJobId;
        
        @InvocableVariable(label='Scheduler Job Name')
        public String schedulerJobName;
        
        @InvocableVariable(label='Scheduler Cron Expression')
        public String schedulerCronExpression;
        
        @InvocableVariable(label='Scheduler Frequency (minutes)')
        public Decimal schedulerFrequencyMinutes;
        
        @InvocableVariable(label='Worker Frequency from Metadata (minutes)')
        public Decimal workerFrequencyMinutesFromMetadata;
        
        @InvocableVariable(label='Scheduler Next Execution')
        public Datetime schedulerNextExecution;
        
        @InvocableVariable(label='Scheduler Next Execution (timezone utilisateur)')
        public String schedulerNextExecutionFormatted;
        
        @InvocableVariable(label='Date/heure actuelle (timezone utilisateur)')
        public String formattedCurrentDateTime;
        
        @InvocableVariable(label='Scheduler State')
        public String schedulerState;
        
        @InvocableVariable(label='Has Worker Active')
        public Boolean hasWorkerActive;
        
        @InvocableVariable(label='Worker Status')
        public String workerStatus;
        
        @InvocableVariable(label='Message')
        public String message;
        
        @InvocableVariable(label='Success')
        public Boolean success;
    }
    
    /*** 
    * @description Gets or modifies AsyncScheduler schedule frequency based on request action
    * @param requests List of GetScheduleRequest with action and optional parameters
    * @return List<ScheduleInfoResponse> List of responses, one per request
    * @Exception 
    ***/ 
    @InvocableMethod(label='Manage Async Scheduler Schedule' description='Gets or modifies AsyncScheduler schedule frequency' category='Async Framework')
    public static List<ScheduleInfoResponse> manageSchedule(List<GetScheduleRequest> requests) {
        List<ScheduleInfoResponse> responses = new List<ScheduleInfoResponse>();
        
        for (GetScheduleRequest request : requests) {
            ScheduleInfoResponse response = new ScheduleInfoResponse();
            response.success = false;
            
            try {
                if (request.action == 'GET_INFO') {
                    response = getScheduleInfo();
                    response.success = true;
                    
                } else if (request.action == 'SCHEDULE_EVERY_MINUTE') {
                    String jobName = String.isNotBlank(request.jobName) ? request.jobName : DEFAULT_JOB_NAME;
                    Boolean useSingle = request.useSingleScheduler == true;
                    String jobId = scheduleEveryMinute(jobName, useSingle);
                    wakeUpWorker();
                    response = getScheduleInfo();
                    response.success = true;
                    response.message = 'Scheduler configured to run every minute. Job ID: ' + jobId;
                    
                } else if (request.action == 'UPDATE_FREQUENCY_METADATA') {
                    if (request.frequencyMinutes != null && request.frequencyMinutes > 0 && request.frequencyMinutes <= 60) {
                        String msg = updateMetadataFrequency(request.frequencyMinutes);
                        response = getScheduleInfo();
                        response.success = true;
                        response.message = msg;
                    } else {
                        response.message = 'Frequency must be between 1 and 60 minutes';
                        response.success = false;
                    }
                    
                } else if (request.action == 'SCHEDULE_CUSTOM') {
                    Integer freq = request.frequencyMinutes != null ? request.frequencyMinutes : AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
                    if (freq <= 0) {
                        response.message = 'Frequency in minutes must be greater than 0';
                        response.success = false;
                    } else {
                        updateMetadataFrequency(freq);
                        String jobName = String.isNotBlank(request.jobName) ? request.jobName : DEFAULT_JOB_NAME;
                        Boolean useSingle = request.useSingleScheduler == true;
                        String jobId = scheduleCustomFrequency(freq, jobName, useSingle);
                        wakeUpWorker();
                        response = getScheduleInfo();
                        response.success = true;
                        response.message = 'Metadata and Scheduler updated: Worker frequency = ' + freq + ' min. Job ID: ' + jobId;
                    }
                    
                } else {
                    response.message = 'Invalid action. Use GET_INFO, SCHEDULE_EVERY_MINUTE, SCHEDULE_CUSTOM, or UPDATE_FREQUENCY_METADATA';
                    response.success = false;
                }
                
            } catch (Exception e) {
                response.message = 'Error: ' + e.getMessage();
                response.success = false;
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    /*** 
    * @description Retrieves current scheduler and worker state
    * @param  
    * @return ScheduleInfoResponse Response with scheduler and worker information
    * @Exception 
    ***/ 
    private static ScheduleInfoResponse getScheduleInfo() {
        ScheduleInfoResponse response = new ScheduleInfoResponse();
        
        List<CronTrigger> schedulerJobs = [
            SELECT Id, CronExpression, NextFireTime, State, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.JobType = '7'
            AND (CronJobDetail.Name LIKE '%Async%Scheduler%' OR CronJobDetail.Name LIKE '%AsyncScheduler%')
            ORDER BY CreatedDate DESC
        ];

        if (!schedulerJobs.isEmpty()) {
            CronTrigger job = schedulerJobs[0];
            response.hasSchedulerJob = true;
            response.schedulerJobId = job.Id;
            response.schedulerJobName = job.CronJobDetail.Name;
            response.schedulerCronExpression = job.CronExpression;
            response.schedulerNextExecution = job.NextFireTime;
            response.schedulerNextExecutionFormatted = job.NextFireTime != null ? DateTimeFormatUtil.formatInUserTimezone(job.NextFireTime) : '';
            response.schedulerState = job.State;
            response.schedulerFrequencyMinutes = parseCronToMinutes(job.CronExpression, schedulerJobs.size());
        } else {
            response.hasSchedulerJob = false;
            response.message = 'No AsyncScheduler job found';
        }
        
        String workerClassName = AsyncWorkerQueueable.class.getName();
        if (workerClassName.contains('.')) {
            Integer lastDotIndex = workerClassName.lastIndexOf('.');
            if (lastDotIndex >= 0 && lastDotIndex < workerClassName.length() - 1) {
                workerClassName = workerClassName.substring(lastDotIndex + 1);
            }
        }
        
        List<AsyncApexJob> activeWorkers = [
            SELECT Id, Status, CreatedDate
            FROM AsyncApexJob 
            WHERE ApexClass.Name = :workerClassName 
            AND Status IN ('Queued', 'Processing', 'Preparing', 'Holding')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        response.hasWorkerActive = !activeWorkers.isEmpty();
        if (!activeWorkers.isEmpty()) {
            response.workerStatus = activeWorkers[0].Status;
        } else {
            response.workerStatus = 'Inactive';
        }
        
        // Worker execution frequency from metadata (used for display and configuration)
        response.workerFrequencyMinutesFromMetadata = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
        
        // Current date/time formatted in the timezone of the user executing the Flow
        response.formattedCurrentDateTime = DateTimeFormatUtil.formatNowInUserTimezone();
        
        return response;
    }
    
    /*** 
    * @description Pads job number with leading zero for display
    * @param num The job number to pad
    * @return String Padded string (e.g. 01 for 1)
    * @Exception 
    ***/ 
    private static String padJobNumber(Integer num) {
        return (num < 10 ? '0' : '') + String.valueOf(num);
    }
    
    /*** 
    * @description Updates Scheduler_Frequency_Minutes__c in Async_Framework_Configuration__mdt
    * @param minutes The new frequency in minutes
    * @return String Message with deployment job ID if applicable
    * @Exception 
    ***/ 
    private static String updateMetadataFrequency(Integer minutes) {
        Metadata.CustomMetadata md = new Metadata.CustomMetadata();
        md.fullName = 'Async_Framework_Configuration__mdt.Default_Configuration';
        md.label = 'Default Configuration';
        
        Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
        val.field = 'Scheduler_Frequency_Minutes__c';
        val.value = minutes;
        md.values.add(val);
        
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(md);
        Id jobId = Test.isRunningTest() ? null : Metadata.Operations.enqueueDeployment(container, null);
        AsyncFrameworkConfig.clearConfig();
        return 'Metadata update queued. Scheduler_Frequency_Minutes = ' + minutes + (jobId != null ? ' (Job: ' + jobId + ')' : '');
    }
    
    /*** 
    * @description Publishes WAKEUP platform event to trigger worker execution
    * @param  
    * @return 
    * @Exception 
    ***/ 
    private static void wakeUpWorker() {
        try {
            EventBus.publish(new Async_WakeUp__e(Event_Type__c = 'WAKEUP'));
        } catch (Exception e) {
            System.debug('AsyncSchedulerSetup: Could not publish WAKEUP event. Worker will start at next Watchdog run. Error: ' + e.getMessage());
        }
    }
    
    /*** 
    * @description Schedules the Async Scheduler to run every minute (backward-compatible overload)
    * @param jobName Name for the scheduled job
    * @return String The scheduled job ID
    * @Exception 
    ***/ 
    public static String scheduleEveryMinute(String jobName) {
        return scheduleEveryMinute(jobName, false);
    }
    
    /*** 
    * @description Schedules the Async Scheduler to run every minute
    * @param jobName Name for the scheduled job
    * @param useSingleScheduler If true, uses one self-rescheduling job; if false, uses multiple cron jobs
    * @return String The scheduled job ID
    * @Exception 
    ***/ 
    public static String scheduleEveryMinute(String jobName, Boolean useSingleScheduler) {
        return scheduleCustomFrequency(1, jobName, useSingleScheduler);
    }
    
    /*** 
    * @description Schedules the Async Scheduler with custom frequency in minutes
    * @param frequencyMinutes Frequency in minutes (1-60)
    * @param jobName Name for the scheduled job
    * @param useSingleScheduler If true, uses one self-rescheduling job; if false, uses multiple cron jobs
    * @return String The scheduled job ID
    * @Exception IllegalArgumentException If frequency is invalid
    ***/ 
    public static String scheduleCustomFrequency(Integer frequencyMinutes, String jobName, Boolean useSingleScheduler) {
        if (String.isBlank(jobName)) jobName = DEFAULT_JOB_NAME;
        if (frequencyMinutes == null || frequencyMinutes <= 0) throw new IllegalArgumentException('Frequency must be greater than 0 minutes');
        if (frequencyMinutes > 60) throw new IllegalArgumentException('Frequency cannot exceed 60 minutes.');
        if (useSingleScheduler == null) useSingleScheduler = false;
        removeExistingSchedules();
        if (useSingleScheduler == true) {
            return scheduleSingleRescheduling(frequencyMinutes, jobName);
        }
        String jobId = null;
        if (frequencyMinutes == 60) {
            jobId = System.schedule(jobName + ' 01', '0 0 * * * ?', new AsyncScheduler());
        } else if (frequencyMinutes >= 1 && frequencyMinutes < 60 && Math.mod(60, frequencyMinutes) == 0) {
            Integer minute = 0;
            Integer intervals = 60 / frequencyMinutes;
            for (Integer i = 0; i < intervals; i++) {
                String cron = '0 ' + minute + ' * * * ?';
                String name = intervals > 1 ? (jobName + ' ' + padJobNumber(i + 1)) : (jobName + ' 01');
                jobId = System.schedule(name, cron, new AsyncScheduler());
                minute += frequencyMinutes;
            }
        } else {
            jobId = System.schedule(jobName + ' 01', '0 0 * * * ?', new AsyncScheduler());
        }
        return jobId;
    }
    
    /*** 
    * @description Creates 1 scheduler that runs in N minutes and reschedules itself after each execution
    * @param frequencyMinutes Frequency in minutes
    * @param jobName Name for the scheduled job
    * @return String The scheduled job ID
    * @Exception 
    ***/ 
    private static String scheduleSingleRescheduling(Integer frequencyMinutes, String jobName) {
        DateTime runTime = DateTime.now().addMinutes(frequencyMinutes);
        String cron = '0 ' + runTime.minute() + ' ' + runTime.hour() + ' ' + runTime.day()
            + ' ' + runTime.month() + ' ? ' + runTime.year();
        String name = jobName + ' 01';
        return System.schedule(name, cron, new AsyncSchedulerSelfRescheduling());
    }
    
    /*** 
    * @description Schedules the Async Scheduler to run every hour
    * @param jobName Name for the scheduled job
    * @return String The scheduled job ID
    * @Exception 
    ***/ 
    public static String scheduleEveryHour(String jobName) {
        return scheduleCustomFrequency(60, jobName, false);
    }
    
    /*** 
    * @description Ensures the Watchdog scheduler is present. Called when parallel workers finish
    *              to restore single-worker mode with watchdog monitoring.
    *              Schedules AsyncSchedulerSelfRescheduling if no Watchdog cron exists.
    * @return Boolean True if scheduler was present or successfully created
    * @Exception 
    ***/ 
    public static Boolean ensureWatchdogSchedulerPresent() {
        // Watchdog jobs: "Async Framework Scheduler 01" etc. - excludes AsyncWorker (no "Scheduler" in name)
        List<CronTrigger> watchdogJobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.JobType = '7'
            AND (CronJobDetail.Name LIKE '%Async Framework Scheduler%' OR CronJobDetail.Name LIKE '%Async%Scheduler%')
            LIMIT 1
        ];
        if (!watchdogJobs.isEmpty()) return true;
        try {
            Integer freq = AsyncFrameworkConfig.getDefaultSchedulerFrequencyMinutes();
            if (freq == null || freq <= 0) freq = 1;
            scheduleSingleRescheduling(freq, DEFAULT_JOB_NAME);
            System.debug('AsyncSchedulerSetup: Watchdog scheduler (Async Framework Scheduler 01) created.');
            return true;
        } catch (Exception e) {
            System.debug('AsyncSchedulerSetup: Failed to create Watchdog scheduler. ' + e.getMessage());
            return false;
        }
    }

    /*** 
    * @description Removes all existing Async Scheduler cron jobs
    * @param  
    * @return Integer Number of jobs removed
    * @Exception 
    ***/ 
    public static Integer removeExistingSchedules() {
        List<CronTrigger> existingJobs = [
            SELECT Id FROM CronTrigger 
            WHERE CronJobDetail.JobType = '7' 
            AND (CronJobDetail.Name LIKE '%Async%Scheduler%' OR CronJobDetail.Name LIKE '%AsyncScheduler%')
        ];
        for (CronTrigger ct : existingJobs) System.abortJob(ct.Id);
        return existingJobs.size();
    }
    
    /*** 
    * @description Parses cron expression and job count to derive frequency in minutes
    * @param cronExpression The cron expression string
    * @param jobCount Number of scheduler jobs
    * @return Decimal Frequency in minutes or null if not parseable
    * @Exception 
    ***/ 
    private static Decimal parseCronToMinutes(String cronExpression, Integer jobCount) {
        if (String.isBlank(cronExpression)) return null;
        List<String> parts = cronExpression.split(' ');
        if (parts.size() < 2) return null;
        String minutePart = parts[1], secondPart = parts[0];
        if (Pattern.matches('\\d+', minutePart) && Pattern.matches('\\d+', secondPart)) {
            return jobCount > 0 ? Decimal.valueOf(60) / jobCount : 60;
        }
        if (minutePart == '0' && secondPart == '0') return 60;
        return null;
    }
}