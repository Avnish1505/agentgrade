/**
 * Agentforce action: reports whether an order is inside the policy return
 * window. Reads RefundPolicy__mdt.Default for the window length. This is a
 * factual check only - it does not decide anything about refunds, and it
 * never throws for a missing order or a malformed Id.
 */
public with sharing class CheckReturnWindow {

    public class Request {
        @InvocableVariable(label='Order Id' description='The Salesforce record Id of the order. Use this when you already have it from a prior action result; it is the more precise lookup.' required=false)
        public String orderId;

        @InvocableVariable(label='Order Number' description='The order number, for example ORD-0042. Use this when the record Id is not known. If both fields are provided, order Id takes precedence.' required=false)
        public String orderNumber;
    }

    public class Result {
        @InvocableVariable(label='Found' description='True if a matching order was found, false otherwise.')
        public Boolean found;

        @InvocableVariable(label='Is Delivered' description='True if the order has a delivered date recorded. If false, days since delivery and the inside-window result do not apply.')
        public Boolean isDelivered;

        @InvocableVariable(label='Inside Window' description='True if the order was delivered within the policy return window. Blank if the order was not found, not yet delivered, or the policy record is missing.')
        public Boolean insideWindow;

        @InvocableVariable(label='Days Since Delivery' description='Whole days between the delivered date and today. Blank if not delivered or not found.')
        public Integer daysSinceDelivery;

        @InvocableVariable(label='Window Days' description='The return window length, in days, used for this check (from RefundPolicy__mdt.Default). Blank if that policy record is missing.')
        public Integer windowDays;

        @InvocableVariable(label='Message' description='A short human-readable explanation, especially when the order was not found or has not shipped yet.')
        public String message;
    }

    @InvocableMethod(label='Check Return Window' description='Reports whether an order is still within the policy return window, and how many days since delivery. Factual only - it does not approve, deny or process any refund. Use it to gather facts before a return decision is made elsewhere.')
    public static List<Result> checkReturnWindow(List<Request> requests) {
        Integer windowDays = getWindowDays();

        Set<Id> validIds = new Set<Id>();
        Set<String> orderNumbers = new Set<String>();
        for (Request req : requests) {
            String rawId = req.orderId != null ? req.orderId.trim() : null;
            if (String.isNotBlank(rawId)) {
                try {
                    validIds.add((Id) rawId);
                } catch (Exception e) {
                    // Not a valid Id format; handled as not-found in buildResult.
                }
            } else if (String.isNotBlank(req.orderNumber)) {
                orderNumbers.add(req.orderNumber.trim());
            }
        }

        Map<Id, Order__c> byId = new Map<Id, Order__c>();
        if (!validIds.isEmpty()) {
            for (Order__c o : [SELECT Id, Name, DeliveredDate__c FROM Order__c WHERE Id IN :validIds]) {
                byId.put(o.Id, o);
            }
        }

        Map<String, Order__c> byOrderNumber = new Map<String, Order__c>();
        if (!orderNumbers.isEmpty()) {
            for (Order__c o : [SELECT Id, Name, DeliveredDate__c FROM Order__c WHERE Name IN :orderNumbers]) {
                byOrderNumber.put(o.Name, o);
            }
        }

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(buildResult(req, byId, byOrderNumber, windowDays));
        }
        return results;
    }

    private static Integer getWindowDays() {
        List<RefundPolicy__mdt> policies = [
            SELECT ReturnWindowDays__c
            FROM RefundPolicy__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (policies.isEmpty() || policies[0].ReturnWindowDays__c == null) {
            return null;
        }
        return Integer.valueOf(policies[0].ReturnWindowDays__c);
    }

    private static Result buildResult(Request req, Map<Id, Order__c> byId, Map<String, Order__c> byOrderNumber, Integer windowDays) {
        Result res = new Result();
        res.windowDays = windowDays;

        String rawId = req.orderId != null ? req.orderId.trim() : null;
        String orderNumber = req.orderNumber != null ? req.orderNumber.trim() : null;

        if (String.isBlank(rawId) && String.isBlank(orderNumber)) {
            res.found = false;
            res.message = 'No order Id or order number was provided.';
            return res;
        }

        Order__c o;
        if (String.isNotBlank(rawId)) {
            try {
                o = byId.get((Id) rawId);
            } catch (Exception e) {
                o = null;
            }
        } else {
            o = byOrderNumber.get(orderNumber);
        }

        if (o == null) {
            res.found = false;
            res.message = String.isNotBlank(rawId)
                ? 'No order found with Id ' + rawId + '.'
                : 'No order found with order number ' + orderNumber + '.';
            return res;
        }

        res.found = true;

        if (o.DeliveredDate__c == null) {
            res.isDelivered = false;
            res.message = 'Order ' + o.Name + ' has not been delivered yet.';
            return res;
        }

        res.isDelivered = true;
        Integer days = o.DeliveredDate__c.daysBetween(Date.today());
        res.daysSinceDelivery = days;
        if (windowDays != null) {
            res.insideWindow = days <= windowDays;
        }
        res.message = 'Order ' + o.Name + ' was delivered ' + days + ' day(s) ago.';
        return res;
    }
}