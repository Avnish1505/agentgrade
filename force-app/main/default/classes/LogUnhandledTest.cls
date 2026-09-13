@isTest
private class LogUnhandledTest {

    @isTest
    static void testHappyPath() {
        LogUnhandled.Request req = new LogUnhandled.Request();
        req.utterance = 'Can you help me file my taxes?';

        Test.startTest();
        List<LogUnhandled.Result> results = LogUnhandled.logUnhandled(new List<LogUnhandled.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        Case c = [SELECT Subject, Description FROM Case WHERE Id = :results[0].caseId];
        System.assertEquals('AgentGrade: Unhandled Utterance', c.Subject);
        System.assertEquals('Can you help me file my taxes?', c.Description);
    }

    // No natural "not found" path exists for this action (there is no lookup),
    // so this covers the equivalent edge case: a blank utterance must still be
    // recorded rather than throwing.
    @isTest
    static void testBlankUtteranceStillRecorded() {
        LogUnhandled.Request req = new LogUnhandled.Request();
        req.utterance = null;

        Test.startTest();
        List<LogUnhandled.Result> results = LogUnhandled.logUnhandled(new List<LogUnhandled.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(String.isNotBlank(results[0].caseId));
    }

    @isTest
    static void testDmlFailureIsReportedNotThrown() {
        LogUnhandled.Request req = new LogUnhandled.Request();
        req.utterance = 'x'.repeat(32001); // exceeds Case.Description's 32000-char limit - must fail cleanly, not throw

        Test.startTest();
        List<LogUnhandled.Result> results = LogUnhandled.logUnhandled(new List<LogUnhandled.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(String.isBlank(results[0].caseId));
        System.assert(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testBulk() {
        List<LogUnhandled.Request> requests = new List<LogUnhandled.Request>();
        for (Integer i = 0; i < 50; i++) {
            LogUnhandled.Request req = new LogUnhandled.Request();
            req.utterance = 'Unhandled message ' + i;
            requests.add(req);
        }

        Test.startTest();
        List<LogUnhandled.Result> results = LogUnhandled.logUnhandled(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (LogUnhandled.Result r : results) {
            System.assertEquals(true, r.success);
        }
        System.assertEquals(50, [SELECT COUNT() FROM Case WHERE Subject = 'AgentGrade: Unhandled Utterance']);
    }
}