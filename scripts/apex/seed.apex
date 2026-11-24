Pricebook2 std = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!std.IsActive) { std.IsActive = true; update std; }

Product2 p1 = new Product2(Name='KAN4 Widget Pro', ProductCode='KAN4-WP', IsActive=true);
Product2 p2 = new Product2(Name='KAN4 Service Plan', ProductCode='KAN4-SP', IsActive=true);
insert new List<Product2>{p1, p2};
PricebookEntry e1 = new PricebookEntry(Pricebook2Id=std.Id, Product2Id=p1.Id, UnitPrice=250, IsActive=true);
PricebookEntry e2 = new PricebookEntry(Pricebook2Id=std.Id, Product2Id=p2.Id, UnitPrice=99, IsActive=true);
insert new List<PricebookEntry>{e1, e2};

Account a1 = new Account(Name='KAN4 Northwind Traders', AccountNumber='KAN4-1001', BillingCity='Melbourne');
Account a2 = new Account(Name='KAN4 Contoso Ltd', AccountNumber='KAN4-1002', BillingCity='Brisbane');
Account a3 = new Account(Name='KAN4 Fabrikam', AccountNumber='KAN4-1003', BillingCity='Perth');
Account a4 = new Account(Name='KAN4 Blue Yonder', AccountNumber='KAN4-2001', BillingCity='Sydney');
Account a5 = new Account(Name='KAN4 Blue Yonder', AccountNumber='KAN4-2002', BillingCity='Melbourne');
insert new List<Account>{a1,a2,a3,a4,a5};
insert new Contact(FirstName='Nora', LastName='KAN4 Buyer', Email='buyer@northwind.example', AccountId=a1.Id);

Order o1 = new Order(AccountId=a1.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,8,10), Status='Draft', Description='KAN4 test');
Order o2 = new Order(AccountId=a1.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,10,5), Status='Draft', Description='KAN4 test');
Order o3 = new Order(AccountId=a1.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,11,18), Status='Draft', Description='KAN4 test');
Order o4 = new Order(AccountId=a2.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,9,12), Status='Draft', Description='KAN4 test');
Order o5 = new Order(AccountId=a4.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,7,1), Status='Draft', Description='KAN4 test');
Order o6 = new Order(AccountId=a5.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,10,20), Status='Draft', Description='KAN4 test');
Order o7 = new Order(AccountId=a5.Id, Pricebook2Id=std.Id, EffectiveDate=Date.newInstance(2026,11,10), Status='Draft', Description='KAN4 test');
insert new List<Order>{o1,o2,o3,o4,o5,o6,o7};

List<OrderItem> items = new List<OrderItem>{
  new OrderItem(OrderId=o1.Id, PricebookEntryId=e2.Id, Quantity=1, UnitPrice=99),
  new OrderItem(OrderId=o2.Id, PricebookEntryId=e1.Id, Quantity=1, UnitPrice=250),
  new OrderItem(OrderId=o3.Id, PricebookEntryId=e1.Id, Quantity=2, UnitPrice=250),
  new OrderItem(OrderId=o3.Id, PricebookEntryId=e2.Id, Quantity=1, UnitPrice=99),
  new OrderItem(OrderId=o4.Id, PricebookEntryId=e1.Id, Quantity=1, UnitPrice=250),
  new OrderItem(OrderId=o5.Id, PricebookEntryId=e2.Id, Quantity=1, UnitPrice=99),
  new OrderItem(OrderId=o6.Id, PricebookEntryId=e1.Id, Quantity=1, UnitPrice=250),
  new OrderItem(OrderId=o7.Id, PricebookEntryId=e2.Id, Quantity=2, UnitPrice=99)
};
insert items;
o1.Status='Activated'; o3.Status='Activated'; o7.Status='Activated';
update new List<Order>{o1,o3,o7};
System.debug('SEED_OK');
