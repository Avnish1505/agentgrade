// Seed synthetic orders, return requests and a refund policy.
// Run with: sf apex run -f scripts/seed_data.apex -o agentgrade
//
// Deliberately include edge cases, because the eval suite depends on them:
//   - orders just inside and just outside the return window
//   - refund amounts just under and just over the policy cap
//
// TODO: adjust field API names to match what you actually created in Phase 1.

// 1. Refund policy
// RefundPolicy__c policy = new RefundPolicy__c(
//     MaxAutoRefund__c = 500,
//     ReturnWindowDays__c = 30
// );
// insert policy;

// 2. Orders
// List<Order__c> orders = new List<Order__c>();
// for (Integer i = 0; i < 150; i++) {
//     orders.add(new Order__c(
//         OrderDate__c = Date.today().addDays(-Math.mod(i * 7, 400)),
//         TotalAmount__c = 100 + Math.mod(i * 37, 2000),
//         Status__c = 'Delivered'
//     ));
// }
// insert orders;

System.debug('TODO: uncomment and adapt once objects exist.');
