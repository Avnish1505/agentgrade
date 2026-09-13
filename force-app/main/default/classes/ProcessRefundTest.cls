@isTest
private class ProcessRefundTest {

    @testSetup
    static void setup() {
        Order__c o = new Order__c(
            CustomerEmail__c = 'refund@example.com',
            Status__c = 'Delivered',
            OrderDate__c = Date.today().addDays(-10),
            DeliveredDate__c = Date.today().addDays(-5)
        );
        insert o;

        OrderItem__c item = new OrderItem__c(
            Name = 'Test Item',
            Order__c = o.Id,
            ProductName__c = 'Widget',
            Quantity__c = 1,
            UnitPrice__c = 50
        );
        insert item;
    }

    @isTest
    static void testHappyPathWholeOrderNoPolicyCheck() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];

        ProcessRefund.Request req = new ProcessRefund.Request();
        req.orderId = o.Id;
        req.amount = 999999; // deliberately far over the $500 policy cap - proves this action does not enforce it
        req.reason = 'Damaged';

        Test.startTest();
        List<ProcessRefund.Result> results = ProcessRefund.processRefund(new List<ProcessRefund.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(String.isNotBlank(results[0].returnRequestId));

        ReturnRequest__c rr = [
            SELECT Order__c, RequestedAmount__c, Outcome__c, Reason__c
            FROM ReturnRequest__c
            WHERE Id = :results[0].returnRequestId
        ];
        System.assertEquals(o.Id, rr.Order__c);
        System.assertEquals(999999, rr.RequestedAmount__c);
        System.assertEquals('Approved', rr.Outcome__c);
        System.assertEquals('Damaged', rr.Reason__c);
    }

    @isTest
    static void testHappyPathWithOrderItem() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];
        OrderItem__c item = [SELECT Id FROM OrderItem__c LIMIT 1];

        ProcessRefund.Request req = new ProcessRefund.Request();
        req.orderId = o.Id;
        req.orderItemId = item.Id;
        req.amount = 50;
        req.reason = 'Wrong item';

        Test.startTest();
        List<ProcessRefund.Result> results = ProcessRefund.processRefund(new List<ProcessRefund.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        ReturnRequest__c rr = [SELECT OrderItem__c FROM ReturnRequest__c WHERE Id = :results[0].returnRequestId];
        System.assertEquals(item.Id, rr.OrderItem__c);
    }

    @isTest
    static void testInvalidOrderIdReturnsFailureNotException() {
        ProcessRefund.Request req = new ProcessRefund.Request();
        req.orderId = 'not-a-real-id';
        req.amount = 10;
        req.reason = 'Damaged';

        Test.startTest();
        List<ProcessRefund.Result> results = ProcessRefund.processRefund(new List<ProcessRefund.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Invalid Order Id'));
    }

    @isTest
    static void testInvalidOrderItemIdReturnsFailureNotException() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];

        ProcessRefund.Request req = new ProcessRefund.Request();
        req.orderId = o.Id;
        req.orderItemId = 'not-a-real-id';
        req.amount = 10;
        req.reason = 'Damaged';

        Test.startTest();
        List<ProcessRefund.Result> results = ProcessRefund.processRefund(new List<ProcessRefund.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Invalid Order Item Id'));
    }

    @isTest
    static void testDmlFailureIsReportedNotThrown() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];

        ProcessRefund.Request req = new ProcessRefund.Request();
        req.orderId = o.Id;
        req.amount = 10;
        req.reason = 'Not a valid picklist value'; // Reason__c is a restricted picklist - this must fail at DML, not be blocked earlier

        Test.startTest();
        List<ProcessRefund.Result> results = ProcessRefund.processRefund(new List<ProcessRefund.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(String.isBlank(results[0].returnRequestId));
        System.assert(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testBulk() {
        Order__c o = [SELECT Id FROM Order__c LIMIT 1];

        List<ProcessRefund.Request> requests = new List<ProcessRefund.Request>();
        for (Integer i = 0; i < 50; i++) {
            ProcessRefund.Request req = new ProcessRefund.Request();
            req.orderId = o.Id;
            req.amount = 10 + i;
            req.reason = 'Changed mind';
            requests.add(req);
        }

        Test.startTest();
        List<ProcessRefund.Result> results = ProcessRefund.processRefund(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (ProcessRefund.Result r : results) {
            System.assertEquals(true, r.success);
        }
        System.assertEquals(50, [SELECT COUNT() FROM ReturnRequest__c]);
    }
}