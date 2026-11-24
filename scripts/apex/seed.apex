// KAN-1 test data seed
Pricebook2 pb = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!pb.IsActive) { pb.IsActive = true; update pb; }

Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :pb.Id AND Product2Id = :prod.Id LIMIT 1];
PricebookEntry pbe;
if (pbes.isEmpty()) {
    pbe = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = prod.Id, UnitPrice = 250, IsActive = true);
    insert pbe;
} else { pbe = pbes[0]; }

Database.DMLOptions dml = new Database.DMLOptions();
dml.DuplicateRuleHeader.AllowSave = true;
List<Account> nw = new List<Account>{
    new Account(Name = 'Northwind Traders', BillingCity = 'Sydney', AccountNumber = 'NW-SYD-001'),
    new Account(Name = 'Northwind Traders', BillingCity = 'Melbourne', AccountNumber = 'NW-MEL-002')
};
Database.insert(nw, dml);

Account acme = [SELECT Id FROM Account WHERE Name = 'Acme' LIMIT 1];
Account gm = [SELECT Id FROM Account WHERE Name = 'Global Media' LIMIT 1];

Contact c = new Contact(FirstName = 'Jamie', LastName = 'Buyer', Email = 'jamie.buyer@acme-demo.com', AccountId = acme.Id);
Database.insert(c, dml);

List<Order> orders = new List<Order>{
    new Order(AccountId = acme.Id, EffectiveDate = Date.newInstance(2026, 8, 15), Status = 'Draft', Pricebook2Id = pb.Id, Description = 'KAN-1 seed'),
    new Order(AccountId = acme.Id, EffectiveDate = Date.newInstance(2026, 9, 20), Status = 'Draft', Pricebook2Id = pb.Id, Description = 'KAN-1 seed'),
    new Order(AccountId = acme.Id, EffectiveDate = Date.newInstance(2026, 10, 30), Status = 'Draft', Pricebook2Id = pb.Id, Description = 'KAN-1 seed'),
    new Order(AccountId = gm.Id, EffectiveDate = Date.newInstance(2026, 10, 5), Status = 'Draft', Pricebook2Id = pb.Id, Description = 'KAN-1 seed'),
    new Order(AccountId = nw[0].Id, EffectiveDate = Date.newInstance(2026, 9, 1), Status = 'Draft', Pricebook2Id = pb.Id, Description = 'KAN-1 seed'),
    new Order(AccountId = nw[1].Id, EffectiveDate = Date.newInstance(2026, 10, 12), Status = 'Draft', Pricebook2Id = pb.Id, Description = 'KAN-1 seed')
};
insert orders;

List<Integer> qty = new List<Integer>{ 2, 4, 6, 3, 1, 5 };
List<OrderItem> items = new List<OrderItem>();
for (Integer i = 0; i < orders.size(); i++) {
    items.add(new OrderItem(OrderId = orders[i].Id, PricebookEntryId = pbe.Id, Quantity = qty[i], UnitPrice = 250));
}
insert items;
System.debug('SEED DONE: ' + orders.size() + ' orders');
