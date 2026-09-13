// One-off verification script for Phase 2 actions against real seeded data.
// Run with: sf apex run -f scripts/verify_actions.apex -o agentgrade
// Not part of the deployed package; kept here only as a record of what was run.

System.debug('=== GetOrderStatus: by order number (ORD-0007, delivered 28 days ago) ===');
GetOrderStatus.Request gosReq1 = new GetOrderStatus.Request();
gosReq1.orderNumber = 'ORD-0007';
GetOrderStatus.Result gosRes1 = GetOrderStatus.getOrderStatus(new List<GetOrderStatus.Request>{ gosReq1 })[0];
System.debug('found=' + gosRes1.found + ' status=' + gosRes1.status + ' orderDate=' + gosRes1.orderDate
    + ' deliveredDate=' + gosRes1.deliveredDate + ' totalAmount=' + gosRes1.totalAmount + ' message=' + gosRes1.message);

System.debug('=== GetOrderStatus: by customer email (customer7@seed.agentgrade.test) ===');
GetOrderStatus.Request gosReq2 = new GetOrderStatus.Request();
gosReq2.customerEmail = 'customer7@seed.agentgrade.test';
GetOrderStatus.Result gosRes2 = GetOrderStatus.getOrderStatus(new List<GetOrderStatus.Request>{ gosReq2 })[0];
System.debug('found=' + gosRes2.found + ' orderNumber=' + gosRes2.orderNumber + ' status=' + gosRes2.status + ' message=' + gosRes2.message);

System.debug('=== GetOrderStatus: not found ===');
GetOrderStatus.Request gosReq3 = new GetOrderStatus.Request();
gosReq3.orderNumber = 'ORD-9999';
GetOrderStatus.Result gosRes3 = GetOrderStatus.getOrderStatus(new List<GetOrderStatus.Request>{ gosReq3 })[0];
System.debug('found=' + gosRes3.found + ' message=' + gosRes3.message);

System.debug('=== CheckReturnWindow: ORD-0007 (delivered 28 days ago, should be INSIDE window) ===');
CheckReturnWindow.Request crwReq1 = new CheckReturnWindow.Request();
crwReq1.orderNumber = 'ORD-0007';
CheckReturnWindow.Result crwRes1 = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ crwReq1 })[0];
System.debug('found=' + crwRes1.found + ' isDelivered=' + crwRes1.isDelivered + ' insideWindow=' + crwRes1.insideWindow
    + ' daysSinceDelivery=' + crwRes1.daysSinceDelivery + ' windowDays=' + crwRes1.windowDays + ' message=' + crwRes1.message);

System.debug('=== CheckReturnWindow: ORD-0010 (delivered 35 days ago, should be OUTSIDE window) ===');
CheckReturnWindow.Request crwReq2 = new CheckReturnWindow.Request();
crwReq2.orderNumber = 'ORD-0010';
CheckReturnWindow.Result crwRes2 = CheckReturnWindow.checkReturnWindow(new List<CheckReturnWindow.Request>{ crwReq2 })[0];
System.debug('found=' + crwRes2.found + ' isDelivered=' + crwRes2.isDelivered + ' insideWindow=' + crwRes2.insideWindow
    + ' daysSinceDelivery=' + crwRes2.daysSinceDelivery + ' windowDays=' + crwRes2.windowDays + ' message=' + crwRes2.message);

Order__c targetOrder = [SELECT Id, Name FROM Order__c WHERE Name = 'ORD-0007' LIMIT 1];
OrderItem__c targetItem = [SELECT Id, Name FROM OrderItem__c WHERE Order__c = :targetOrder.Id LIMIT 1];

System.debug('=== ProcessRefund: real order/item, amount deliberately over the $500 cap (proves no validation) ===');
ProcessRefund.Request prReq = new ProcessRefund.Request();
prReq.orderId = targetOrder.Id;
prReq.orderItemId = targetItem.Id;
prReq.amount = 750;
prReq.reason = 'Damaged';
ProcessRefund.Result prRes = ProcessRefund.processRefund(new List<ProcessRefund.Request>{ prReq })[0];
System.debug('success=' + prRes.success + ' returnRequestId=' + prRes.returnRequestId + ' message=' + prRes.message);

ReturnRequest__c createdRR = [SELECT Id, Order__c, OrderItem__c, RequestedAmount__c, Outcome__c, Reason__c FROM ReturnRequest__c WHERE Id = :prRes.returnRequestId];
System.debug('confirmed on record: RequestedAmount__c=' + createdRR.RequestedAmount__c + ' Outcome__c=' + createdRR.Outcome__c + ' Reason__c=' + createdRR.Reason__c);

System.debug('=== CreateEscalationCase: escalating the return request just created ===');
CreateEscalationCase.Request cecReq = new CreateEscalationCase.Request();
cecReq.orderId = targetOrder.Id;
cecReq.reason = 'Amount over cap';
cecReq.contextSummary = 'Customer requested $750 refund on ' + targetOrder.Name + '; auto-approve cap is $500.';
cecReq.returnRequestId = createdRR.Id;
CreateEscalationCase.Result cecRes = CreateEscalationCase.createEscalationCase(new List<CreateEscalationCase.Request>{ cecReq })[0];
System.debug('success=' + cecRes.success + ' caseId=' + cecRes.caseId + ' caseNumber=' + cecRes.caseNumber + ' message=' + cecRes.message);

ReturnRequest__c updatedRR = [SELECT Outcome__c, DecisionReason__c, EscalationCase__c FROM ReturnRequest__c WHERE Id = :createdRR.Id];
System.debug('confirmed on record: Outcome__c=' + updatedRR.Outcome__c + ' DecisionReason__c=' + updatedRR.DecisionReason__c + ' EscalationCase__c=' + updatedRR.EscalationCase__c);

System.debug('=== LogUnhandled ===');
LogUnhandled.Request luReq = new LogUnhandled.Request();
luReq.utterance = 'Can you help me file my taxes?';
LogUnhandled.Result luRes = LogUnhandled.logUnhandled(new List<LogUnhandled.Request>{ luReq })[0];
System.debug('success=' + luRes.success + ' caseId=' + luRes.caseId + ' message=' + luRes.message);

Case loggedCase = [SELECT Subject, Description FROM Case WHERE Id = :luRes.caseId];
System.debug('confirmed on record: Subject=' + loggedCase.Subject + ' Description=' + loggedCase.Description);
