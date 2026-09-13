/**
 * Agentforce action: records that the agent could not handle the user's
 * request, so a human can review it later. Does not attempt to answer the
 * utterance itself. Uses a Case with a distinct subject rather than a new
 * object, since this is a low-volume fallback, not a first-class record type.
 */
public with sharing class LogUnhandled {

    private static final String SUBJECT_PREFIX = 'AgentGrade: Unhandled Utterance';

    public class Request {
        @InvocableVariable(label='Utterance' description='The user message the agent could not handle, verbatim.' required=true)
        public String utterance;
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if the unhandled utterance was recorded.')
        public Boolean success;

        @InvocableVariable(label='Case Id' description='The Id of the case created to record this. Blank if recording failed.')
        public String caseId;

        @InvocableVariable(label='Message' description='A short human-readable result or error explanation.')
        public String message;
    }

    @InvocableMethod(label='Log Unhandled Utterance' description='Records a case for a user message the agent could not route or act on, for later human review. Use this only as a last-resort fallback when no other action applies - never in place of answering a question the agent can actually handle.')
    public static List<Result> logUnhandled(List<Request> requests) {
        List<Case> casesToInsert = new List<Case>();
        for (Request req : requests) {
            Case c = new Case();
            c.Subject = SUBJECT_PREFIX;
            c.Description = req.utterance;
            casesToInsert.add(c);
        }

        Database.SaveResult[] saveResults = Database.insert(casesToInsert, false);

        List<Result> results = new List<Result>();
        for (Database.SaveResult sr : saveResults) {
            Result res = new Result();
            if (sr.isSuccess()) {
                res.success = true;
                res.caseId = sr.getId();
                res.message = 'Unhandled utterance recorded.';
            } else {
                res.success = false;
                res.message = sr.getErrors().isEmpty() ? 'Unknown error recording utterance.' : sr.getErrors()[0].getMessage();
            }
            results.add(res);
        }
        return results;
    }
}