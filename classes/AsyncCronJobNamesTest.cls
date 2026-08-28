/*** 
* @author Emmanuel (EMM) 
* @date 28/08/2026 
* @description Tests de AsyncCronJobNames : unicite des noms generes et recherche
*              des jobs cron encore capables de se declencher.
***/ 
@isTest
private class AsyncCronJobNamesTest {

    /*** 
    * @description Expression cron one-shot pour dans n minutes, comme celles du framework.
    ***/ 
    private static String cronInMinutes(Integer minutes) {
        DateTime runTime = DateTime.now().addMinutes(minutes);
        return '0 ' + runTime.minute() + ' ' + runTime.hour() + ' '
            + runTime.day() + ' ' + runTime.month() + ' ? ' + runTime.year();
    }

    @isTest
    static void testUniqueNameKeepsPrefix() {
        String generated = AsyncCronJobNames.uniqueName(AsyncCronJobNames.WORKER_PREFIX);

        Assert.isTrue(
            generated.startsWith(AsyncCronJobNames.WORKER_PREFIX),
            'Le prefixe doit rester interrogeable en LIKE'
        );
        Assert.areNotEqual(
            AsyncCronJobNames.WORKER_PREFIX,
            generated,
            'Le nom genere ne doit jamais etre le prefixe nu'
        );
    }

    @isTest
    static void testUniqueNameFallbackOnBlankPrefix() {
        Assert.isTrue(
            String.isNotBlank(AsyncCronJobNames.uniqueName(null)),
            'Un prefixe vide doit produire un nom de repli'
        );
    }

    @isTest
    static void testFindLiveJobIdReturnsNullWhenNoJob() {
        Assert.isNull(
            AsyncCronJobNames.findLiveJobId('Prefixe Async Inexistant'),
            'Aucun job ne doit etre trouve pour ce prefixe'
        );
    }

    @isTest
    static void testFindLiveJobIdReturnsNullOnBlankPrefix() {
        Assert.isNull(
            AsyncCronJobNames.findLiveJobId(null),
            'Un prefixe vide ne doit rien remonter'
        );
    }

    @isTest
    static void testFindLiveJobIdFindsScheduledJob() {
        // Prefixe dedie : les CronTrigger reels de l'org sont visibles depuis les tests, et
        // un vrai watchdog en cours ferait remonter un autre Id que celui planifie ici.
        String testPrefix = 'Async Test Watchdog';
        Id scheduledId = System.schedule(
            AsyncCronJobNames.uniqueName(testPrefix),
            cronInMinutes(30),
            new AsyncScheduler()
        );

        Id found = AsyncCronJobNames.findLiveJobId(testPrefix);

        Assert.areEqual(
            scheduledId,
            found,
            'Le job planifie et non declenche doit etre retrouve'
        );
    }

    @isTest
    static void testTwoConsecutiveSchedulesDoNotCollide() {
        Id firstId = System.schedule(
            AsyncCronJobNames.uniqueName(AsyncCronJobNames.WORKER_PREFIX),
            cronInMinutes(30),
            new AsyncScheduler()
        );
        Id secondId = System.schedule(
            AsyncCronJobNames.uniqueName(AsyncCronJobNames.WORKER_PREFIX),
            cronInMinutes(31),
            new AsyncScheduler()
        );

        Assert.areNotEqual(
            firstId,
            secondId,
            'Deux planifications successives ne doivent pas se marcher dessus'
        );
    }
}
