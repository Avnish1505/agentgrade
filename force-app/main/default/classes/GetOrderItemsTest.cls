@isTest
private class GetOrderItemsTest {

    @testSetup
    static void setup() {
        Order__c withItems = new Order__c(
            CustomerEmail__c = 'withitems@example.com',
            Status__c = 'Delivered',
            OrderDate__c = Date.today().addDays(-20),
            DeliveredDate__c = Date.today().addDays(-15)
        );
        Order__c noItems = new Order__c(
            CustomerEmail__c = 'noitems@example.com',
            Status__c = 'Pending',
            OrderDate__c = Date.today()
        );
        insert new List<Order__c>{ withItems, noItems };

        insert new List<OrderItem__c>{
            new OrderItem__c(
                Order__c = withItems.Id,
                Name = 'Item 1',
                ProductName__c = 'Widget',
                Quantity__c = 1,
                UnitPrice__c = 100,
                IsReturnable__c = true
            ),
            new OrderItem__c(
                Order__c = withItems.Id,
                Name = 'Item 2',
                ProductName__c = 'Gadget',
                Quantity__c = 2,
                UnitPrice__c = 50,
                IsReturnable__c = false
            )
        };
    }

    @isTest
    static void testHappyPathMultipleItems() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'withitems@example.com'];
        GetOrderItems.Request req = new GetOrderItems.Request();
        req.orderId = o.Id;

        Test.startTest();
        List<GetOrderItems.Result> results = GetOrderItems.getOrderItems(new List<GetOrderItems.Request>{ req });
        Test.stopTest();

        GetOrderItems.Result res = results[0];
        System.assertEquals(true, res.found);
        System.assertEquals(2, res.orderItemId.size());
        System.assertEquals(2, res.productName.size());
        System.assertEquals(2, res.lineTotal.size());
        System.assertEquals(2, res.isReturnable.size());

        // Parallel-list integrity: find "Gadget" and check its paired values.
        Integer gadgetIdx = res.productName.indexOf('Gadget');
        System.assert(gadgetIdx >= 0);
        System.assertEquals(100, res.lineTotal[gadgetIdx]); // 2 * 50
        System.assertEquals(false, res.isReturnable[gadgetIdx]);

        Integer widgetIdx = res.productName.indexOf('Widget');
        System.assertEquals(100, res.lineTotal[widgetIdx]); // 1 * 100
        System.assertEquals(true, res.isReturnable[widgetIdx]);
    }

    @isTest
    static void testOrderWithNoItems() {
        Order__c o = [SELECT Id FROM Order__c WHERE CustomerEmail__c = 'noitems@example.com'];
        GetOrderItems.Request req = new GetOrderItems.Request();
        req.orderId = o.Id;

        Test.startTest();
        List<GetOrderItems.Result> results = GetOrderItems.getOrderItems(new List<GetOrderItems.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals(0, results[0].orderItemId.size());
        System.assert(String.isNotBlank(results[0].message));
    }

    @isTest
    static void testNotFoundBadIdAndBlank() {
        GetOrderItems.Request nonexistent = new GetOrderItems.Request();
        nonexistent.orderId = '001000000000000AAA'; // well-formed but no such record

        GetOrderItems.Request badId = new GetOrderItems.Request();
        badId.orderId = 'not-a-real-id';

        GetOrderItems.Request blank = new GetOrderItems.Request();

        Test.startTest();
        List<GetOrderItems.Result> results = GetOrderItems.getOrderItems(
            new List<GetOrderItems.Request>{ nonexistent, badId, blank }
        );
        Test.stopTest();

        System.assertEquals(3, results.size());
        for (GetOrderItems.Result r : results) {
            System.assertEquals(false, r.found);
            System.assertEquals(0, r.orderItemId.size());
            System.assert(String.isNotBlank(r.message));
        }
    }

    @isTest
    static void testBulk() {
        List<Order__c> bulkOrders = new List<Order__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkOrders.add(new Order__c(
                CustomerEmail__c = 'bulk' + i + '@example.com',
                Status__c = 'Delivered',
                OrderDate__c = Date.today().addDays(-10),
                DeliveredDate__c = Date.today().addDays(-5)
            ));
        }
        insert bulkOrders;

        List<OrderItem__c> bulkItems = new List<OrderItem__c>();
        for (Order__c o : bulkOrders) {
            bulkItems.add(new OrderItem__c(
                Order__c = o.Id,
                Name = 'Bulk Item',
                ProductName__c = 'Widget',
                Quantity__c = 1,
                UnitPrice__c = 25,
                IsReturnable__c = true
            ));
        }
        insert bulkItems;

        List<GetOrderItems.Request> requests = new List<GetOrderItems.Request>();
        for (Order__c o : bulkOrders) {
            GetOrderItems.Request req = new GetOrderItems.Request();
            req.orderId = o.Id;
            requests.add(req);
        }

        Test.startTest();
        List<GetOrderItems.Result> results = GetOrderItems.getOrderItems(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (GetOrderItems.Result r : results) {
            System.assertEquals(true, r.found);
            System.assertEquals(1, r.orderItemId.size());
        }
    }
}