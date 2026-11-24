@isTest
private class OrderAgent_Test {

    @testSetup
    static void setup() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.AllowSave = true;
        List<Account> accts = new List<Account>{
            new Account(Name = 'Zeta Widgets', AccountNumber = 'ZW-100', BillingCity = 'Perth'),
            new Account(Name = 'Twin Co', BillingCity = 'Sydney'),
            new Account(Name = 'Twin Co', BillingCity = 'Melbourne'),
            new Account(Name = 'Empty Orders Pty')
        };
        Database.insert(accts, dml);
        Database.insert(new Contact(LastName = 'Buyer', Email = 'buyer@zeta-test.com', AccountId = accts[0].Id), dml);

        Id pbId = Test.getStandardPricebookId();
        Product2 p = new Product2(Name = 'Test Widget', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pbId, Product2Id = p.Id, UnitPrice = 100, IsActive = true);
        insert pbe;

        List<Order> orders = new List<Order>{
            new Order(AccountId = accts[0].Id, EffectiveDate = Date.today().addDays(-30), Status = 'Draft', Pricebook2Id = pbId),
            new Order(AccountId = accts[0].Id, EffectiveDate = Date.today().addDays(-2), Status = 'Draft', Pricebook2Id = pbId)
        };
        insert orders;
        insert new List<OrderItem>{
            new OrderItem(OrderId = orders[0].Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100),
            new OrderItem(OrderId = orders[1].Id, PricebookEntryId = pbe.Id, Quantity = 3, UnitPrice = 100)
        };
    }

    private static OrderAgent_FindCustomer.Output find(String q) {
        OrderAgent_FindCustomer.Input i = new OrderAgent_FindCustomer.Input();
        i.customerQuery = q;
        return OrderAgent_FindCustomer.find(new List<OrderAgent_FindCustomer.Input>{ i })[0];
    }

    private static OrderAgent_GetLastOrder.Output last(String accId) {
        OrderAgent_GetLastOrder.Input i = new OrderAgent_GetLastOrder.Input();
        i.accountId = accId;
        return OrderAgent_GetLastOrder.getLastOrder(new List<OrderAgent_GetLastOrder.Input>{ i })[0];
    }

    @isTest static void singleMatchByName() {
        OrderAgent_FindCustomer.Output o = find('Zeta Widgets');
        System.assertEquals('1', o.matchCount);
        System.assertNotEquals('', o.accountId);
    }

    @isTest static void singleMatchByAccountNumber() {
        System.assertEquals('1', find('ZW-100').matchCount);
    }

    @isTest static void matchByEmail() {
        OrderAgent_FindCustomer.Output o = find('buyer@zeta-test.com');
        System.assertEquals('1', o.matchCount);
        System.assert(o.matchList.contains('Zeta Widgets'));
    }

    @isTest static void multipleMatches() {
        OrderAgent_FindCustomer.Output o = find('Twin Co');
        System.assertEquals('2', o.matchCount);
        System.assertEquals('', o.accountId);
        System.assert(o.matchList.contains('Sydney') && o.matchList.contains('Melbourne'));
    }

    @isTest static void noMatchAndBlank() {
        System.assertEquals('0', find('Nonexistent Corp 12345').matchCount);
        System.assertEquals('0', find('  ').matchCount);
        System.assertEquals('0', find('nobody@nowhere-test.com').matchCount);
    }

    @isTest static void lastOrderReturnsNewest() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Zeta Widgets'];
        Order newest = [SELECT OrderNumber FROM Order WHERE AccountId = :a.Id ORDER BY EffectiveDate DESC LIMIT 1];
        OrderAgent_GetLastOrder.Output o = last(a.Id);
        System.assertEquals('True', o.found);
        System.assertEquals(newest.OrderNumber, o.orderNumber);
        System.assert(o.orderUrl.contains('/lightning/r/Order/'));
        System.assert(o.totalAmount.contains('300'));
    }

    @isTest static void noOrders() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Empty Orders Pty'];
        OrderAgent_GetLastOrder.Output o = last(a.Id);
        System.assertEquals('False', o.found);
        System.assert(o.message.contains('no orders'));
    }

    @isTest static void invalidAccountId() {
        System.assertEquals('False', last('not-an-id').found);
        System.assertEquals('False', last(null).found);
        System.assertEquals('False', last('001000000000000AAA').found);
    }
}
