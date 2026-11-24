@isTest
private class KAN4_OrderLookupServiceTest {

    @testSetup
    static void setup() {
        Id pbId = Test.getStandardPricebookId();
        Product2 p = new Product2(Name = 'Test Widget', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pbId, Product2Id = p.Id, UnitPrice = 100, IsActive = true);
        insert pbe;

        Account normal = new Account(Name = 'Test Normal Co', AccountNumber = 'T-1');
        Account empty = new Account(Name = 'Test Empty Co', AccountNumber = 'T-2');
        Account dupA = new Account(Name = 'Test Dup Co', AccountNumber = 'T-3', BillingCity = 'Sydney');
        Account dupB = new Account(Name = 'Test Dup Co', AccountNumber = 'T-4', BillingCity = 'Melbourne');
        insert new List<Account>{ normal, empty, dupA, dupB };
        insert new Contact(LastName = 'Buyer', Email = 'buyer@test.example', AccountId = normal.Id);

        Order older = new Order(AccountId = normal.Id, Pricebook2Id = pbId, EffectiveDate = Date.today().addDays(-30), Status = 'Draft');
        Order newer = new Order(AccountId = normal.Id, Pricebook2Id = pbId, EffectiveDate = Date.today().addDays(-1), Status = 'Draft');
        Order dupOrder = new Order(AccountId = dupB.Id, Pricebook2Id = pbId, EffectiveDate = Date.today(), Status = 'Draft');
        insert new List<Order>{ older, newer, dupOrder };
        insert new List<OrderItem>{
            new OrderItem(OrderId = older.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100),
            new OrderItem(OrderId = newer.Id, PricebookEntryId = pbe.Id, Quantity = 3, UnitPrice = 100),
            new OrderItem(OrderId = dupOrder.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100)
        };
    }

    private static KAN4_OrderLookupService.Output run(String q, String acctId) {
        KAN4_OrderLookupService.Input inp = new KAN4_OrderLookupService.Input();
        inp.customerQuery = q;
        inp.accountId = acctId;
        return KAN4_OrderLookupService.lookup(new List<KAN4_OrderLookupService.Input>{ inp })[0];
    }

    @isTest static void foundReturnsLatestOrder() {
        Order newer = [SELECT OrderNumber FROM Order WHERE Account.Name = 'Test Normal Co' ORDER BY EffectiveDate DESC LIMIT 1];
        KAN4_OrderLookupService.Output out = run('Test Normal Co', null);
        System.assertEquals('FOUND', out.status);
        System.assertEquals(newer.OrderNumber, out.orderNumber);
        System.assert(out.totalAmount.startsWith('300'), out.totalAmount);
        System.assert(out.orderUrl.contains('/lightning/r/Order/'));
        System.assert(out.message.contains(newer.OrderNumber));
    }

    @isTest static void accountNumberMatch() {
        System.assertEquals('FOUND', run('T-1', null).status);
    }

    @isTest static void emailMatch() {
        KAN4_OrderLookupService.Output out = run('buyer@test.example', null);
        System.assertEquals('FOUND', out.status);
        System.assertEquals('Test Normal Co', out.accountName);
    }

    @isTest static void unknownEmailNotFound() {
        System.assertEquals('NOT_FOUND', run('nobody@test.example', null).status);
    }

    @isTest static void partialNameMatch() {
        System.assertEquals('FOUND', run('Normal', null).status);
    }

    @isTest static void noOrders() {
        KAN4_OrderLookupService.Output out = run('Test Empty Co', null);
        System.assertEquals('NO_ORDERS', out.status);
        System.assert(out.message.contains('no orders'));
    }

    @isTest static void multipleMatchesThenChoose() {
        KAN4_OrderLookupService.Output out = run('Test Dup Co', null);
        System.assertEquals('MULTIPLE_MATCHES', out.status);
        System.assert(out.candidates.contains('Melbourne'));
        Account dupB = [SELECT Id FROM Account WHERE AccountNumber = 'T-4'];
        KAN4_OrderLookupService.Output chosen = run('Test Dup Co', dupB.Id);
        System.assertEquals('FOUND', chosen.status);
        System.assertEquals(dupB.Id, chosen.accountId);
    }

    @isTest static void invalidAccountIdFallsBackToQuery() {
        System.assertEquals('FOUND', run('Test Normal Co', 'not-an-id').status);
    }

    @isTest static void notFound() {
        KAN4_OrderLookupService.Output out = run('Zzyzx Industries', null);
        System.assertEquals('NOT_FOUND', out.status);
        System.assert(out.message.contains('account number'));
    }

    @isTest static void blankQueryNotFound() {
        System.assertEquals('NOT_FOUND', run('  ', null).status);
    }

    @isTest static void restrictedUserSeesNoData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniq = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(Alias = 'kan4min', Email = 'kan4min' + uniq + '@test.example',
            EmailEncodingKey = 'UTF-8', LastName = 'Restricted', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = p.Id, TimeZoneSidKey = 'Australia/Melbourne',
            Username = 'kan4min' + uniq + '@test.example');
        insert u;
        KAN4_OrderLookupService.Output out;
        System.runAs(u) {
            out = run('Test Normal Co', null);
        }
        System.assertNotEquals('FOUND', out.status, 'Restricted user must not see order data');
    }
}
