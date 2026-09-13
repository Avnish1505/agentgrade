@isTest
private class GetOrderStatusTest {

    @testSetup
    static void setup() {
        List<Order__c> orders = new List<Order__c>();
        orders.add(new Order__c(
            CustomerEmail__c = 'alice@example.com',
            Status__c = 'Delivered',
            OrderDate__c = Date.today().addDays(-40),
            DeliveredDate__c = Date.today().addDays(-35),
            TotalAmount__c = 120.50
        ));
        orders.add(new Order__c(
            CustomerEmail__c = 'alice@example.com',
            Status__c = 'Shipped',
            OrderDate__c = Date.today().addDays(-5),
            TotalAmount__c = 75.00
        ));
        insert orders;
    }

    @isTest
    static void testFoundByOrderNumber() {
        Order__c o = [SELECT Name FROM Order__c WHERE CustomerEmail__c = 'alice@example.com' ORDER BY OrderDate__c ASC LIMIT 1];

        GetOrderStatus.Request req = new GetOrderStatus.Request();
        req.orderNumber = o.Name;

        Test.startTest();
        List<GetOrderStatus.Result> results = GetOrderStatus.getOrderStatus(new List<GetOrderStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].found);
        System.assertEquals(o.Name, results[0].orderNumber);
        System.assertEquals('Delivered', results[0].status);
        System.assertEquals(120.50, results[0].totalAmount);
    }

    @isTest
    static void testFoundByEmailReturnsMostRecentOrder() {
        GetOrderStatus.Request req = new GetOrderStatus.Request();
        req.customerEmail = 'alice@example.com';

        Test.startTest();
        List<GetOrderStatus.Result> results = GetOrderStatus.getOrderStatus(new List<GetOrderStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found);
        System.assertEquals('Shipped', results[0].status); // placed 5 days ago, the more recent of the two
    }

    @isTest
    static void testNotFound() {
        GetOrderStatus.Request byNumber = new GetOrderStatus.Request();
        byNumber.orderNumber = 'ORD-9999';

        GetOrderStatus.Request byEmail = new GetOrderStatus.Request();
        byEmail.customerEmail = 'nobody@example.com';

        GetOrderStatus.Request blank = new GetOrderStatus.Request();

        Test.startTest();
        List<GetOrderStatus.Result> results = GetOrderStatus.getOrderStatus(
            new List<GetOrderStatus.Request>{ byNumber, byEmail, blank }
        );
        Test.stopTest();

        System.assertEquals(3, results.size());
        for (GetOrderStatus.Result r : results) {
            System.assertEquals(false, r.found);
            System.assert(String.isNotBlank(r.message));
        }
    }

    @isTest
    static void testBulk() {
        List<Order__c> bulkOrders = new List<Order__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkOrders.add(new Order__c(
                CustomerEmail__c = 'bulk' + i + '@example.com',
                Status__c = 'Pending',
                OrderDate__c = Date.today(),
                TotalAmount__c = 10 * i
            ));
        }
        insert bulkOrders;

        List<GetOrderStatus.Request> requests = new List<GetOrderStatus.Request>();
        for (Order__c o : bulkOrders) {
            GetOrderStatus.Request req = new GetOrderStatus.Request();
            req.customerEmail = o.CustomerEmail__c;
            requests.add(req);
        }

        Test.startTest();
        List<GetOrderStatus.Result> results = GetOrderStatus.getOrderStatus(requests);
        Test.stopTest();

        System.assertEquals(50, results.size());
        for (GetOrderStatus.Result r : results) {
            System.assertEquals(true, r.found);
        }
    }
}