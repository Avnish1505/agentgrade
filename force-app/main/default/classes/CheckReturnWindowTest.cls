@isTest
private class CheckReturnWindowTest {

    @testSetup
    static void setup() {
        List<Order__c> orders = new List<Order__c>();
        // Inside window: RefundPolicy.Default.ReturnWindowDays__c is 30.
        orders.add(new Order__c(
            CustomerEmail__c = 'inside@example.com',
            Status__c = 'Delivered',
            OrderDate__c = Date.today().addDays(-20),
            DeliveredDate__c = Date.today().addDays(-15)
        ));
        // Outside window.
        orders.add(new Order__c(
            CustomerEmail__c = 'outside@example.com',
            Status__c = 'Delivered',
            OrderDate__c = Date.today().addDays(-60),
            DeliveredDate__c = Date.today().addDays(-40)
        ));
        // Not delivered yet.
        orders.add(new Order__c(
            CustomerEmail__c = 'pending@example.com',
            Status__c = 'Shipped',
            OrderDate__c = Date.today().addDays(-2)
        ));
        insert orders;
    }

    @isTest
    static void testInsideWindowById() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'inside@example.com'];
        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderId = o.Id;

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals(true, results[0].isDelivered);
        System.assertEquals(true, results[0].insideWindow);
        System.assertEquals(15, results[0].daysSinceDelivery);
        System.assertEquals(30, results[0].windowDays);
    }

    @isTest
    static void testOutsideWindowByOrderNumber() {
        Order__c o = [SELECT Name FROM Order__c WHERE CustomerEmail__c = 'outside@example.com'];
        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderNumber = o.Name;

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals(false, results[0].insideWindow);
        System.assertEquals(40, results[0].daysSinceDelivery);
    }

    @isTest
    static void testNotYetDelivered() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'pending@example.com'];
        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderId = o.Id;

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals(false, results[0].isDelivered);
        System.assertEquals(null, results[0].insideWindow);
    }

    @isTest
    static void testNotFoundAndInvalidId() {
        CheckReturnWindow.Request notFound = new CheckReturnWindow.Request();
        notFound.orderNumber = 'ORD-9999';

        CheckReturnWindow.Request badId = new CheckReturnWindow.Request();
        badId.orderId = 'not-a-real-id';

        CheckReturnWindow.Request blank = new CheckReturnWindow.Request();

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(
            new List<CheckReturnWindow.Request>{ notFound, badId, blank }
        );
        Test.stopTest();

        System.assertEquals(3, results.size());
        for (CheckReturnWindow.Result r : results) {
            System.assertEquals(false, r.found);
        }
    }

    @isTest
    static void testBulk() {
        List<Order__c> bulkOrders = new List<Order__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkOrders.add(new Order__c(
                CustomerEmail__c = 'bulk' + i + '@example.com',
                Status__c = 'Delivered',
                OrderDate__c = Date.today().addDays(-30),
                DeliveredDate__c = Date.today().addDays(-10)
            ));
        }
        insert bulkOrders;

        List<CheckReturnWindow.Request> requests = new List<CheckReturnWindow.Request>();
        for (Order__c o : bulkOrders) {
            CheckReturnWindow.Request req = new CheckReturnWindow.Request();
            req.orderId = o.Id;
            requests.add(req);
        }

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (CheckReturnWindow.Result r : results) {
            System.assertEquals(true, r.found);
            System.assertEquals(true, r.insideWindow);
        }
    }
}