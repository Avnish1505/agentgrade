/**
 * Agentforce action: creates a standard Case for a human to handle, and
 * optionally marks an existing ReturnRequest__c as escalated and links it
 * to that case. This is how the agent or the Phase 3 gate hands off
 * anything it should not decide itself.
 */
public with sharing class CreateEscalationCase {

    public class Request {
        @InvocableVariable(label='Order Id' description='The Salesforce record Id of the order this escalation concerns. Recorded in the case description for a human to trace, since Case has no direct order relationship.' required=true)
        public String orderId;

        @InvocableVariable(label='Reason' description='Why this is being escalated to a human, in a few words. Becomes the case subject.' required=true)
        public String reason;

        @InvocableVariable(label='Context Summary' description='A short summary of the conversation or situation for the human who picks up the case. A few sentences, not a full transcript.' required=true)
        public String contextSummary;

        @InvocableVariable(label='Return Request Id' description='The Id of an existing ReturnRequest__c to mark Escalated and link to this case. Leave blank if this escalation is not about a specific return request.' required=false)
        public String returnRequestId;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if the case was created.')
        public Boolean success;

        @InvocableVariable(label='Case Id' description='The Id of the created case. Blank if creation failed.')
        public String caseId;

        @InvocableVariable(label='Case Number' description='The case number, for reference in conversation. Blank if creation failed.')
        public String caseNumber;

        @InvocableVariable(label='Message' description='A short human-readable result or error explanation.')
        public String message;
    }

    @InvocableMethod(label='Create Escalation Case' description='Creates a case for a human to handle and, if a return request Id is supplied, marks that return request Escalated and links it to the case. Use this whenever the agent or the policy gate determines a request needs a human - never to approve or deny a refund itself.')
    public static List<Result> createEscalationCase(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Case> casesToInsert = new List<Case>();

        for (Request req : requests) {
            Case c = new Case();
            c.Subject = 'Escalation: ' + safeTruncate(req.reason, 240);
            c.Description = 'Order: ' + req.orderId + '\n\n' + req.contextSummary;
            casesToInsert.add(c);
        }

        Database.SaveResult[] caseSaveResults = Database.insert(casesToInsert, false);

        List<ReturnRequest__c> returnRequestsToUpdate = new List<ReturnRequest__c>();
        List<Integer> rrUpdateResultIndex = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Database.SaveResult sr = caseSaveResults[i];
            Result res = new Result();
            results.add(res);

            if (!sr.isSuccess()) {
                res.success = false;
                res.message = sr.getErrors().isEmpty() ? 'Unknown error creating case.' : sr.getErrors()[0].getMessage();
                continue;
            }

            res.success = true;
            res.caseId = sr.getId();
            res.message = 'Escalation case created.';

            if (String.isNotBlank(req.returnRequestId)) {
                try {
                    ReturnRequest__c rr = new ReturnRequest__c(Id = req.returnRequestId);
                    rr.EscalationCase__c = sr.getId();
                    rr.Outcome__c = 'Escalated';
                    rr.DecisionReason__c = req.reason;
                    returnRequestsToUpdate.add(rr);
                    rrUpdateResultIndex.add(i);
                } catch (Exception e) {
                    res.message += ' (Warning: invalid return request Id, could not link or update it.)';
                }
            }
        }

        if (!returnRequestsToUpdate.isEmpty()) {
            Database.SaveResult[] rrSaveResults = Database.update(returnRequestsToUpdate, false);
            for (Integer j = 0; j < rrSaveResults.size(); j++) {
                if (!rrSaveResults[j].isSuccess()) {
                    Result res = results[rrUpdateResultIndex[j]];
                    Database.SaveResult rrResult = rrSaveResults[j];
                    res.message += ' (Warning: could not update the return request: ' +
                        (rrResult.getErrors().isEmpty() ? 'unknown error' : rrResult.getErrors()[0].getMessage()) + ')';
                }
            }
        }

        Set<Id> createdCaseIds = new Set<Id>();
        for (Result res : results) {
            if (res.success && String.isNotBlank(res.caseId)) {
                createdCaseIds.add((Id) res.caseId);
            }
        }
        if (!createdCaseIds.isEmpty()) {
            Map<Id, Case> caseNumbers = new Map<Id, Case>([SELECT Id, CaseNumber FROM Case WHERE Id IN :createdCaseIds]);
            for (Result res : results) {
                if (res.success && caseNumbers.containsKey((Id) res.caseId)) {
                    res.caseNumber = caseNumbers.get((Id) res.caseId).CaseNumber;
                }
            }
        }

        return results;
    }

    private static String safeTruncate(String s, Integer maxLen) {
        if (s == null) {
            return '';
        }
        return s.length() > maxLen ? s.substring(0, maxLen) : s;
    }
}