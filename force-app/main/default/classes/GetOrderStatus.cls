/**
 * Agentforce action: looks up a single Order__c by order number or by
 * customer email, and reports its status fields. Read-only, bulk-safe, and
 * never throws for a missing order - it reports "not found" instead.
 */
public with sharing class GetOrderStatus {

    public class Request {
        @InvocableVariable(label='Order Number' description='The order number to look up, for example ORD-0042. Use this when the caller knows the exact order number; it is the more precise lookup.' required=false)
        public String orderNumber;

        @InvocableVariable(label='Customer Email' description='The customer email to look up the most recent order for. Use this only when the order number is not known. If both fields are provided, order number takes precedence.' required=false)
        public String customerEmail;
    }

    public class Result {
        @InvocableVariable(label='Found' description='True if a matching order was found, false otherwise.')
        public Boolean found;

        @InvocableVariable(label='Order Number' description='The order number of the matched order. Blank if not found.')
        public String orderNumber;

        @InvocableVariable(label='Status' description='The order status: Pending, Shipped, Delivered or Cancelled. Blank if not found.')
        public String status;

        @InvocableVariable(label='Order Date' description='The date the order was placed. Blank if not found.')
        public Date orderDate;

        @InvocableVariable(label='Delivered Date' description='The date the order was delivered. Blank if not yet delivered or not found.')
        public Date deliveredDate;

        @InvocableVariable(label='Total Amount' description='The order total. Blank if not found.')
        public Decimal totalAmount;

        @InvocableVariable(label='Message' description='A short human-readable explanation, especially when the order was not found or no input was given.')
        public String message;
    }

    @InvocableMethod(label='Get Order Status' description='Looks up one order by order number or customer email and returns its status, dates and total. Use this to answer "where is my order" or "what is the status of order X" questions. Do not use this to check return eligibility - use Check Return Window for that.')
    public static List<Result> getOrderStatus(List<Request> requests) {
        Set<String> orderNumbers = new Set<String>();
        Set<String> emails = new Set<String>();
        for (Request req : requests) {
            String orderNumber = req.orderNumber != null ? req.orderNumber.trim() : null;
            String email = req.customerEmail != null ? req.customerEmail.trim() : null;
            if (String.isNotBlank(orderNumber)) {
                orderNumbers.add(orderNumber);
            } else if (String.isNotBlank(email)) {
                emails.add(email);
            }
        }

        Map<String, Order__c> byOrderNumber = new Map<String, Order__c>();
        if (!orderNumbers.isEmpty()) {
            for (Order__c o : [
                SELECT Name, Status__c, OrderDate__c, DeliveredDate__c, TotalAmount__c
                FROM Order__c
                WHERE Name IN :orderNumbers
            ]) {
                byOrderNumber.put(o.Name, o);
            }
        }

        // Most recent order per email: iterate results ordered by OrderDate__c
        // descending and keep only the first one seen for each address.
        Map<String, Order__c> byEmail = new Map<String, Order__c>();
        if (!emails.isEmpty()) {
            for (Order__c o : [
                SELECT Name, CustomerEmail__c, Status__c, OrderDate__c, DeliveredDate__c, TotalAmount__c
                FROM Order__c
                WHERE CustomerEmail__c IN :emails
                ORDER BY OrderDate__c DESC NULLS LAST
            ]) {
                if (!byEmail.containsKey(o.CustomerEmail__c)) {
                    byEmail.put(o.CustomerEmail__c, o);
                }
            }
        }

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(buildResult(req, byOrderNumber, byEmail));
        }
        return results;
    }

    private static Result buildResult(Request req, Map<String, Order__c> byOrderNumber, Map<String, Order__c> byEmail) {
        Result res = new Result();
        String orderNumber = req.orderNumber != null ? req.orderNumber.trim() : null;
        String email = req.customerEmail != null ? req.customerEmail.trim() : null;

        if (String.isBlank(orderNumber) && String.isBlank(email)) {
            res.found = false;
            res.message = 'No order number or customer email was provided.';
            return res;
        }

        Order__c o = String.isNotBlank(orderNumber) ? byOrderNumber.get(orderNumber) : byEmail.get(email);

        if (o == null) {
            res.found = false;
            res.message = String.isNotBlank(orderNumber)
                ? 'No order found with order number ' + orderNumber + '.'
                : 'No order found for customer email ' + email + '.';
            return res;
        }

        res.found = true;
        res.orderNumber = o.Name;
        res.status = o.Status__c;
        res.orderDate = o.OrderDate__c;
        res.deliveredDate = o.DeliveredDate__c;
        res.totalAmount = o.TotalAmount__c;
        res.message = 'Order found.';
        return res;
    }
}