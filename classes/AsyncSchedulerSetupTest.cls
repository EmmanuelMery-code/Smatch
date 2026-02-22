/***
* @description Test class for AsyncSchedulerSetup invocable action.
***/
@isTest
public with sharing class AsyncSchedulerSetupTest {

    @isTest
    static void testManageSchedule_GET_INFO() {
        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'GET_INFO';

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].success != null);
    }

    @isTest
    static void testManageSchedule_SCHEDULE_EVERY_MINUTE() {
        AsyncSchedulerSetup.removeExistingSchedules();

        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'SCHEDULE_EVERY_MINUTE';
        req.jobName = 'Async Test Scheduler';

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].success);
    }

    @isTest
    static void testManageSchedule_SCHEDULE_EVERY_MINUTE_Single() {
        AsyncSchedulerSetup.removeExistingSchedules();

        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'SCHEDULE_EVERY_MINUTE';
        req.useSingleScheduler = true;

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].success);
    }

    @isTest
    static void testManageSchedule_SCHEDULE_CUSTOM() {
        AsyncSchedulerSetup.removeExistingSchedules();

        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'SCHEDULE_CUSTOM';
        req.frequencyMinutes = 5;
        req.useSingleScheduler = true;

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(results[0].success);
    }

    @isTest
    static void testManageSchedule_InvalidAction() {
        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'INVALID';

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(!results[0].success);
        Assert.isTrue(results[0].message.contains('Invalid'));
    }

    @isTest
    static void testScheduleEveryMinute_Overload() {
        AsyncSchedulerSetup.removeExistingSchedules();

        String jobId = AsyncSchedulerSetup.scheduleEveryMinute('Async Test 01');

        Assert.isTrue(String.isNotBlank(jobId));
    }

    @isTest
    static void testScheduleEveryHour() {
        AsyncSchedulerSetup.removeExistingSchedules();

        String jobId = AsyncSchedulerSetup.scheduleEveryHour('Async Hourly Test');

        Assert.isTrue(String.isNotBlank(jobId));
    }

    @isTest
    static void testEnsureWatchdogSchedulerPresent() {
        AsyncSchedulerSetup.removeExistingSchedules();

        Boolean result = AsyncSchedulerSetup.ensureWatchdogSchedulerPresent();

        Assert.isTrue(result);
    }

    @isTest
    static void testRemoveExistingSchedules() {
        System.schedule('Async Temp', '0 0 * * * ?', new AsyncScheduler());

        Integer removed = AsyncSchedulerSetup.removeExistingSchedules();

        Assert.isTrue(removed >= 1);
    }

    @isTest
    static void testManageSchedule_UPDATE_FREQUENCY_METADATA() {
        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'UPDATE_FREQUENCY_METADATA';
        req.frequencyMinutes = 2;

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
    }

    @isTest
    static void testManageSchedule_SCHEDULE_CUSTOM_InvalidFrequency() {
        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'SCHEDULE_CUSTOM';
        req.frequencyMinutes = 0;

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(!results[0].success);
    }

    @isTest
    static void testScheduleCustomFrequency_Exceeds60() {
        try {
            AsyncSchedulerSetup.scheduleCustomFrequency(61, 'Test', false);
            Assert.fail('Should throw for frequency > 60');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('60'));
        }
    }

    @isTest
    static void testManageSchedule_UPDATE_FREQUENCY_METADATA_InvalidFreq() {
        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'UPDATE_FREQUENCY_METADATA';
        req.frequencyMinutes = 0;

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(!results[0].success);
        Assert.isTrue(results[0].message.contains('1') && results[0].message.contains('60'));
    }

    @isTest
    static void testManageSchedule_UPDATE_FREQUENCY_METADATA_Exceeds60() {
        AsyncSchedulerSetup.GetScheduleRequest req = new AsyncSchedulerSetup.GetScheduleRequest();
        req.action = 'UPDATE_FREQUENCY_METADATA';
        req.frequencyMinutes = 61;

        List<AsyncSchedulerSetup.ScheduleInfoResponse> results = AsyncSchedulerSetup.manageSchedule(new List<AsyncSchedulerSetup.GetScheduleRequest>{ req });

        Assert.isTrue(!results.isEmpty());
        Assert.isTrue(!results[0].success);
    }

    @isTest
    static void testScheduleCustomFrequency_ZeroThrows() {
        try {
            AsyncSchedulerSetup.scheduleCustomFrequency(0, 'Test', false);
            Assert.fail('Should throw for frequency 0');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('0') || e.getMessage().contains('greater'));
        }
    }

    @isTest
    static void testScheduleCustomFrequency_BlankJobName() {
        AsyncSchedulerSetup.removeExistingSchedules();

        String jobId = AsyncSchedulerSetup.scheduleCustomFrequency(1, null, false);

        Assert.isTrue(String.isNotBlank(jobId));
    }
}
