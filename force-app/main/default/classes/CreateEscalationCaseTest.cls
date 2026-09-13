@isTest
private class CreateEscalationCaseTest {

    @testSetup
    static void setup() {
        Order__c o = new Order__c(
            CustomerEmail__c = 'escalate@example.com',
            Status__c = 'Delivered',
            OrderDate__c = Date.today().addDays(-10),
            DeliveredDate__c = Date.today().addDays(-5)
        );
        insert o;

        ReturnRequest__c rr = new ReturnRequest__c(
            Order__c = o.Id,
            RequestedAmount__c = 600,
            Reason__c = 'Damaged',
            Outcome__c = 'Pending'
        );
        insert rr;
    }

    @isTest
    static void testHappyPathWithoutReturnRequest() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];

        CreateEscalationCase.Request req = new CreateEscalationCase.Request();
        req.orderId = o.Id;
        req.reason = 'Amount over cap';
        req.contextSummary = 'Customer requested a $600 refund; the auto-approve cap is $500.';

        Test.startTest();
        List<CreateEscalationCase.Result> results = CreateEscalationCase.createEscalationCase(new List<CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(String.isNotBlank(results[0].caseId));
        System.assert(String.isNotBlank(results[0].caseNumber));

        Case c = [SELECT Subject, Description FROM Case WHERE Id = :results[0].caseId];
        System.assert(c.Subject.startsWith('Escalation:'));
        System.assert(c.Description.contains(o.Id));
    }

    @isTest
    static void testHappyPathWithReturnRequestLinksAndUpdates() {
        ReturnRequest__c rr = [SELECT Id, Order__c FROM ReturnRequest__c LIMIT 1];

        CreateEscalationCase.Request req = new CreateEscalationCase.Request();
        req.orderId = rr.Order__c;
        req.reason = 'Amount over cap';
        req.contextSummary = 'Customer requested a $600 refund; the auto-approve cap is $500.';
        req.returnRequestId = rr.Id;

        Test.startTest();
        List<CreateEscalationCase.Result> results = CreateEscalationCase.createEscalationCase(new List<CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);

        ReturnRequest__c updated = [
            SELECT Outcome__c, DecisionReason__c, EscalationCase__c
            FROM ReturnRequest__c
            WHERE Id = :rr.Id
        ];
        System.assertEquals('Escalated', updated.Outcome__c);
        System.assertEquals('Amount over cap', updated.DecisionReason__c);
        System.assertEquals(results[0].caseId, updated.EscalationCase__c);
    }

    @isTest
    static void testInvalidReturnRequestIdStillCreatesCase() {
        CreateEscalationCase.Request req = new CreateEscalationCase.Request();
        req.orderId = [SELECT Id FROM Order__c LIMIT 1].Id;
        req.reason = 'Test';
        req.contextSummary = 'Test summary';
        req.returnRequestId = 'not-a-real-id';

        Test.startTest();
        List<CreateEscalationCase.Result> results = CreateEscalationCase.createEscalationCase(new List<CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].message.contains('Warning'));
    }

    @isTest
    static void testCaseDmlFailureIsReportedNotThrown() {
        CreateEscalationCase.Request req = new CreateEscalationCase.Request();
        req.orderId = [SELECT Id FROM Order__c LIMIT 1].Id;
        req.reason = 'Test';
        req.contextSummary = 'x'.repeat(32001); // exceeds Case.Description's 32000-char limit - must fail cleanly, not throw

        Test.startTest();
        List<CreateEscalationCase.Result> results = CreateEscalationCase.createEscalationCase(new List<CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(String.isBlank(results[0].caseId));
        System.assert(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testReturnRequestUpdateFailureIsReportedAsWarning() {
        // A correctly-formatted but nonexistent ReturnRequest__c Id: insert a
        // throwaway record, delete it, then reuse its Id. Passes the Id-cast
        // guard, then fails at the Database.update DML step itself.
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];
        ReturnRequest__c throwaway = new ReturnRequest__c(Order__c = o.Id, Outcome__c = 'Pending');
        insert throwaway;
        Id deletedId = throwaway.Id;
        delete throwaway;

        CreateEscalationCase.Request req = new CreateEscalationCase.Request();
        req.orderId = o.Id;
        req.reason = 'Test';
        req.contextSummary = 'Test summary';
        req.returnRequestId = deletedId;

        Test.startTest();
        List<CreateEscalationCase.Result> results = CreateEscalationCase.createEscalationCase(new List<CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success); // the case itself was still created
        System.assert(results[0].message.contains('Warning'));
    }

    @isTest
    static void testBulk() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];

        List<CreateEscalationCase.Request> requests = new List<CreateEscalationCase.Request>();
        for (Integer i = 0; i < 50; i++) {
            CreateEscalationCase.Request req = new CreateEscalationCase.Request();
            req.orderId = o.Id;
            req.reason = 'Bulk reason ' + i;
            req.contextSummary = 'Summary ' + i;
            requests.add(req);
        }

        Test.startTest();
        List<CreateEscalationCase.Result> results = CreateEscalationCase.createEscalationCase(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (CreateEscalationCase.Result r : results) {
            System.assertEquals(true, r.success);
        }
    }
}