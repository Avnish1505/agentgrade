/**
 * Agentforce action: lists the line items on a single Order__c, so a caller
 * can resolve a product mentioned in conversation to a specific OrderItem__c
 * Id before checking return eligibility or processing a refund. Read-only,
 * bulk-safe, and never throws for a missing order or a malformed Id - it
 * reports "not found" instead, with empty lists.
 */
public with sharing class GetOrderItems {

    public class Request {
        @InvocableVariable(label='Order Id' description='The Salesforce record Id of the order to list line items for.' required=true)
        public String orderId;
    }

    public class Result {
        @InvocableVariable(label='Found' description='True if a matching order was found, false otherwise. An order with no line items is still found = true, with empty lists.')
        public Boolean found;

        @InvocableVariable(label='Order Item Id' description='The Salesforce record Id of each line item on the order, in the same order as the other list outputs.')
        public List<String> orderItemId = new List<String>();

        @InvocableVariable(label='Product Name' description='The product name of each line item, parallel to Order Item Id.')
        public List<String> productName = new List<String>();

        @InvocableVariable(label='Line Total' description='The line total of each line item, parallel to Order Item Id.')
        public List<Decimal> lineTotal = new List<Decimal>();

        @InvocableVariable(label='Is Returnable' description='Whether each line item is marked returnable, parallel to Order Item Id.')
        public List<Boolean> isReturnable = new List<Boolean>();

        @InvocableVariable(label='Message' description='A short human-readable explanation, especially when the order was not found or a malformed Id was given.')
        public String message;
    }

    @InvocableMethod(label='Get Order Items' description='Lists the line items on an order: Id, product name, line total and whether each is marked returnable. Use this to find the specific OrderItem__c Id for a product the customer named, before checking return eligibility or processing a refund.')
    public static List<Result> getOrderItems(List<Request> requests) {
        Set<Id> validOrderIds = new Set<Id>();
        for (Request req : requests) {
            String rawId = req.orderId != null ? req.orderId.trim() : null;
            if (String.isNotBlank(rawId)) {
                try {
                    validOrderIds.add((Id) rawId);
                } catch (Exception e) {
                    // Not a valid Id format; handled as not-found in buildResult.
                }
            }
        }

        Map<Id, Order__c> ordersById = new Map<Id, Order__c>();
        if (!validOrderIds.isEmpty()) {
            for (Order__c o : [SELECT Id FROM Order__c WHERE Id IN :validOrderIds]) {
                ordersById.put(o.Id, o);
            }
        }

        Map<Id, List<OrderItem__c>> itemsByOrderId = new Map<Id, List<OrderItem__c>>();
        if (!ordersById.isEmpty()) {
            for (OrderItem__c item : [
                SELECT Id, ProductName__c, LineTotal__c, IsReturnable__c, Order__c
                FROM OrderItem__c
                WHERE Order__c IN :ordersById.keySet()
            ]) {
                if (!itemsByOrderId.containsKey(item.Order__c)) {
                    itemsByOrderId.put(item.Order__c, new List<OrderItem__c>());
                }
                itemsByOrderId.get(item.Order__c).add(item);
            }
        }

        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(buildResult(req, ordersById, itemsByOrderId));
        }
        return results;
    }

    private static Result buildResult(Request req, Map<Id, Order__c> ordersById, Map<Id, List<OrderItem__c>> itemsByOrderId) {
        Result res = new Result();
        String rawId = req.orderId != null ? req.orderId.trim() : null;

        if (String.isBlank(rawId)) {
            res.found = false;
            res.message = 'No order Id was provided.';
            return res;
        }

        Id orderId;
        try {
            orderId = (Id) rawId;
        } catch (Exception e) {
            res.found = false;
            res.message = 'The order Id ' + rawId + ' is not a valid Id.';
            return res;
        }

        if (!ordersById.containsKey(orderId)) {
            res.found = false;
            res.message = 'No order found with Id ' + rawId + '.';
            return res;
        }

        res.found = true;
        List<OrderItem__c> items = itemsByOrderId.get(orderId);
        if (items == null || items.isEmpty()) {
            res.message = 'Order found, but it has no line items.';
            return res;
        }

        for (OrderItem__c item : items) {
            res.orderItemId.add(item.Id);
            res.productName.add(item.ProductName__c);
            res.lineTotal.add(item.LineTotal__c);
            res.isReturnable.add(item.IsReturnable__c);
        }
        res.message = 'Found ' + items.size() + ' line item(s).';
        return res;
    }
}
