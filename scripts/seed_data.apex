// Seed synthetic orders and line items for Phase 1.
// Run with: sf apex run -f scripts/seed_data.apex -o agentgrade
//
// Idempotent: deletes every previously seeded Order__c (identified by the
// reserved @seed.agentgrade.test email domain) before inserting. Deleting
// Order__c cascades to its OrderItem__c children automatically (master-detail).
//
// Deliberately included edge cases, because the Phase 5 eval harness depends
// on them existing every time this script is run:
//   - orders delivered exactly 28, 29, 31 and 35 days ago (the policy return
//     window is 30 days, so this straddles the boundary on both sides)
//   - line items with LineTotal__c of exactly 450, 499, 501 and 900 (the
//     auto-approve refund cap is 500, so this straddles that boundary too)
//   - at least 5 cancelled orders

String SEED_DOMAIN = '@seed.agentgrade.test';

// 1. Clean up any previous run.
List<Order__c> previouslySeeded = [
    SELECT Id FROM Order__c WHERE CustomerEmail__c LIKE :('%' + SEED_DOMAIN)
];
if (!previouslySeeded.isEmpty()) {
    delete previouslySeeded;
    System.debug('Deleted ' + previouslySeeded.size() + ' previously seeded orders.');
}

List<String> productNames = new List<String>{ 'Widget', 'Gadget', 'Gizmo', 'Doohickey', 'Thingamajig' };
List<String> statuses = new List<String>{ 'Pending', 'Shipped', 'Delivered', 'Cancelled' };

Integer totalOrders = 150;
List<Order__c> orders = new List<Order__c>();

for (Integer i = 0; i < totalOrders; i++) {
    Order__c o = new Order__c();
    o.CustomerEmail__c = 'customer' + i + SEED_DOMAIN;
    o.Status__c = statuses[Math.mod(i, statuses.size())];
    Integer daysAgo = Math.mod(i * 7, 400) + 1;
    o.OrderDate__c = Date.today().addDays(-daysAgo);
    orders.add(o);
}

// Reserve indices 0-5: at least 5 cancelled orders (spec asks for 5; 6 given).
for (Integer i = 0; i < 6; i++) {
    orders[i].Status__c = 'Cancelled';
    orders[i].DeliveredDate__c = null;
}

// Reserve indices 6-9: the required delivered-date edge cases.
Integer[] edgeDeliveredDaysAgo = new Integer[]{ 28, 29, 31, 35 };
for (Integer i = 0; i < edgeDeliveredDaysAgo.size(); i++) {
    Order__c o = orders[6 + i];
    o.Status__c = 'Delivered';
    o.DeliveredDate__c = Date.today().addDays(-edgeDeliveredDaysAgo[i]);
    o.OrderDate__c = o.DeliveredDate__c.addDays(-5);
}

// Reserve indices 10-13: dedicated orders for the required line-total edge cases.
for (Integer i = 10; i <= 13; i++) {
    orders[i].Status__c = 'Delivered';
    orders[i].DeliveredDate__c = orders[i].OrderDate__c.addDays(4);
}

// Fill in a plausible DeliveredDate__c for every other Delivered order.
for (Integer i = 14; i < orders.size(); i++) {
    if (orders[i].Status__c == 'Delivered') {
        orders[i].DeliveredDate__c = orders[i].OrderDate__c.addDays(3 + Math.mod(i, 5));
    }
}

insert orders;
System.debug('Inserted ' + orders.size() + ' orders.');

// 2. Line items.
List<OrderItem__c> items = new List<OrderItem__c>();
Map<Integer, Decimal> orderTotals = new Map<Integer, Decimal>();

// Edge-case line totals: one dedicated item per reserved order (10-13),
// quantity 1 so LineTotal__c == UnitPrice__c exactly.
Decimal[] edgeLineTotals = new Decimal[]{ 450, 499, 501, 900 };
for (Integer i = 0; i < edgeLineTotals.size(); i++) {
    Integer orderIdx = 10 + i;
    OrderItem__c item = new OrderItem__c();
    item.Name = 'Seed Item ' + orderIdx + '-0';
    item.Order__c = orders[orderIdx].Id;
    item.ProductName__c = productNames[Math.mod(orderIdx, productNames.size())];
    item.Quantity__c = 1;
    item.UnitPrice__c = edgeLineTotals[i];
    items.add(item);
    orderTotals.put(orderIdx, edgeLineTotals[i]);
}

// Everything else: 1 to 3 line items per order, deterministic pseudo-random spread.
for (Integer i = 0; i < orders.size(); i++) {
    if (i >= 10 && i <= 13) {
        continue; // already has its dedicated edge-case item
    }
    Integer lineCount = 1 + Math.mod(i, 3);
    Decimal orderTotal = 0;
    for (Integer j = 0; j < lineCount; j++) {
        OrderItem__c item = new OrderItem__c();
        item.Name = 'Seed Item ' + i + '-' + j;
        item.Order__c = orders[i].Id;
        item.ProductName__c = productNames[Math.mod(i + j, productNames.size())];
        Decimal qty = 1 + Math.mod(i + j, 4);
        Decimal price = 10 + Math.mod((i * 13) + (j * 37), 300);
        item.Quantity__c = qty;
        item.UnitPrice__c = price;
        items.add(item);
        orderTotal += qty * price;
    }
    orderTotals.put(i, orderTotal);
}

insert items;
System.debug('Inserted ' + items.size() + ' order items.');

// 3. Roll up TotalAmount__c on each order from its own items (not a rollup
// summary field in this schema, so it is set here explicitly).
for (Integer i = 0; i < orders.size(); i++) {
    orders[i].TotalAmount__c = orderTotals.get(i);
}
update orders;
System.debug('Updated TotalAmount__c on ' + orders.size() + ' orders.');

System.debug('Seed complete: ' + orders.size() + ' orders, ' + items.size() + ' order items.');
