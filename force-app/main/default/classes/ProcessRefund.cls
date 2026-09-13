/**
 * Agentforce action: creates an approved ReturnRequest__c for the given
 * order and amount.
 *
 * DELIBERATE DESIGN: this is a plain executor with NO policy validation.
 * It does not check the refund cap, the return window, or whether the item
 * belongs to the order - none of that. All policy enforcement lives in the
 * Phase 3 Agent Script gate, on purpose, so Phase 5 can measure the
 * difference between running the agent with and without that gate. Do not
 * add validation here.
 *
 * The only error handling in this class is format safety (an unparseable
 * Id fails that one request cleanly instead of throwing for the whole
 * batch) - that is not policy, it is just not crashing on bad input.
 */
public with sharing class ProcessRefund {

    public class Request {
        @InvocableVariable(label='Order Id' description='The Salesforce record Id of the order being refunded.' required=true)
        public String orderId;

        @InvocableVariable(label='Order Item Id' description='The Salesforce record Id of the specific line item being refunded, if this is for one item rather than the whole order. Leave blank for a whole-order refund.' required=false)
        public String orderItemId;

        @InvocableVariable(label='Amount' description='The refund amount to record. Not checked against any policy cap by this action.' required=true)
        public Decimal amount;

        @InvocableVariable(label='Reason' description='The return reason: Damaged, Wrong item, Not as described, or Changed mind.' required=true)
        public String reason;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if the return request was created.')
        public Boolean success;

        @InvocableVariable(label='Return Request Id' description='The Id of the created ReturnRequest__c record. Blank if creation failed.')
        public String returnRequestId;

        @InvocableVariable(label='Message' description='A short human-readable result or error explanation.')
        public String message;
    }

    @InvocableMethod(label='Process Refund' description='Creates an approved return request for the stated amount, with no policy checks of any kind - it does not verify the refund cap, the return window, or item ownership. Only call this after policy has already been enforced elsewhere in the conversation flow.')
    public static List<Result> processRefund(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<ReturnRequest__c> toInsert = new List<ReturnRequest__c>();
        List<Integer> insertIndexToResultIndex = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Result res = new Result();
            results.add(res);

            ReturnRequest__c rr = new ReturnRequest__c();
            Boolean ok = true;

            try {
                rr.Order__c = req.orderId;
            } catch (Exception e) {
                ok = false;
                res.success = false;
                res.message = 'Invalid Order Id: ' + req.orderId;
            }

            if (ok && String.isNotBlank(req.orderItemId)) {
                try {
                    rr.OrderItem__c = req.orderItemId;
                } catch (Exception e) {
                    ok = false;
                    res.success = false;
                    res.message = 'Invalid Order Item Id: ' + req.orderItemId;
                }
            }

            if (ok) {
                rr.RequestedAmount__c = req.amount;
                rr.Reason__c = req.reason;
                rr.Outcome__c = 'Approved';
                toInsert.add(rr);
                insertIndexToResultIndex.add(i);
            }
        }

        if (!toInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(toInsert, false);
            for (Integer j = 0; j < saveResults.size(); j++) {
                Database.SaveResult sr = saveResults[j];
                Result res = results[insertIndexToResultIndex[j]];
                if (sr.isSuccess()) {
                    res.success = true;
                    res.returnRequestId = sr.getId();
                    res.message = 'Return request created and approved.';
                } else {
                    res.success = false;
                    res.message = sr.getErrors().isEmpty()
                        ? 'Unknown error creating return request.'
                        : sr.getErrors()[0].getMessage();
                }
            }
        }

        return results;
    }
}