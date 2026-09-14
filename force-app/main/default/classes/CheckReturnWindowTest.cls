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

    @isTest
    static void testItemHappyPath() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'inside@example.com'];
        OrderItem__c item = new OrderItem__c(
            Order__c = o.Id,
            Name = 'Return Item',
            ProductName__c = 'Widget',
            Quantity__c = 1,
            UnitPrice__c = 250,
            IsReturnable__c = true
        );
        insert item;

        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderId = o.Id;
        req.orderItemId = item.Id;

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals(250, results[0].lineTotal);
        System.assertEquals(true, results[0].isReturnable);
    }

    @isTest
    static void testItemNotFound() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'inside@example.com'];

        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderId = o.Id;
        req.orderItemId = '001000000000000AAA'; // well-formed but no such record

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        // The order itself is still found; only the item-level fields are blank.
        System.assertEquals(true, results[0].found);
        System.assertEquals(null, results[0].lineTotal);
        System.assertEquals(null, results[0].isReturnable);
    }

    @isTest
    static void testItemBelongsToWrongOrder() {
        Order__c targetOrder = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'inside@example.com'];
        Order__c otherOrder = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'outside@example.com'];

        OrderItem__c itemOnOtherOrder = new OrderItem__c(
            Order__c = otherOrder.Id,
            Name = 'Wrong Order Item',
            ProductName__c = 'Gizmo',
            Quantity__c = 1,
            UnitPrice__c = 999,
            IsReturnable__c = true
        );
        insert itemOnOtherOrder;

        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderId = targetOrder.Id; // asking about targetOrder...
        req.orderItemId = itemOnOtherOrder.Id; // ...but the item belongs to otherOrder

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        // The order is still resolved and its window facts still reported,
        // but the item fields must not leak a value from the wrong order -
        // this is the check that stops a mismatched Id from being trusted.
        System.assertEquals(true, results[0].found);
        System.assertEquals(true, results[0].isDelivered);
        System.assertEquals(null, results[0].lineTotal);
        System.assertEquals(null, results[0].isReturnable);
    }

    @isTest
    static void testItemMalformedId() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'inside@example.com'];

        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderId = o.Id;
        req.orderItemId = 'not-a-real-id'; // not Id-shaped at all, not just nonexistent

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals(null, results[0].lineTotal);
        System.assertEquals(null, results[0].isReturnable);
    }

    @isTest
    static void testItemBulk() {
        List<Order__c> bulkOrders = new List<Order__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkOrders.add(new Order__c(
                CustomerEmail__c = 'itembulk' + i + '@example.com',
                Status__c = 'Delivered',
                OrderDate__c = Date.today().addDays(-30),
                DeliveredDate__c = Date.today().addDays(-10)
            ));
        }
        insert bulkOrders;

        List<OrderItem__c> bulkItems = new List<OrderItem__c>();
        for (Order__c o : bulkOrders) {
            bulkItems.add(new OrderItem__c(
                Order__c = o.Id,
                Name = 'Bulk Return Item',
                ProductName__c = 'Doohickey',
                Quantity__c = 1,
                UnitPrice__c = 40,
                IsReturnable__c = false
            ));
        }
        insert bulkItems;

        List<CheckReturnWindow.Request> requests = new List<CheckReturnWindow.Request>();
        for (Integer i = 0; i < bulkOrders.size(); i++) {
            CheckReturnWindow.Request req = new CheckReturnWindow.Request();
            req.orderId = bulkOrders[i].Id;
            req.orderItemId = bulkItems[i].Id;
            requests.add(req);
        }

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (CheckReturnWindow.Result r : results) {
            System.assertEquals(true, r.found);
            System.assertEquals(40, r.lineTotal);
            System.assertEquals(false, r.isReturnable);
        }
    }
}