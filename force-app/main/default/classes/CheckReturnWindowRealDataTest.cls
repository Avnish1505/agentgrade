// Separate from CheckReturnWindowTest deliberately: a test class containing
// a @testSetup method cannot also have @isTest(SeeAllData=true) methods (a
// platform rule, confirmed by a real deploy rejection), and this one test
// needs SeeAllData.
//
// Why: this org's test-context AutoNumber counter has drifted to 6+ digits
// after a long session of repeated test runs (verified directly: a fresh
// @testSetup insert now gets a name like "ORD-100302", while real
// production DML is still at "ORD-0301" - the two counters have diverged).
// A regex of exactly ORD-\d{4} - matching real, current, customer-facing
// order numbers - can never match a freshly test-inserted record's name in
// this environment anymore. Using a real seeded order (which does have a
// genuine 4-digit name) is the only way to test the positive
// sentence-extraction path honestly without changing the regex to
// something other than what was specified.
@isTest(SeeAllData=true)
private class CheckReturnWindowRealDataTest {

    @isTest
    static void testOrderNumberExtractedFromRawSentence() {
        List<Order__c> realOrders = [SELECT Id, Name FROM Order__c WHERE Status__c = 'Delivered' LIMIT 1];
        if (realOrders.isEmpty()) {
            return; // no real seeded data available to test against in this org right now
        }
        Order__c o = realOrders[0];
        String sentence = 'I would like to return the Widget from order ' + o.Name + ', it arrived damaged.';
        CheckReturnWindow.Request req = new CheckReturnWindow.Request();
        req.orderNumber = sentence;

        Test.startTest();
        List<CheckReturnWindow.Result> results = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].found, 'orderName=' + o.Name + ' sentence=' + sentence + ' message=' + results[0].message);
        System.assertEquals(o.Id, results[0].orderId);
    }
}
