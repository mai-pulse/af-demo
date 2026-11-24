/**
 * KAN-4: Read-only order lookup for the Order Lookup Assistant employee agent.
 * Runs with sharing and all queries use USER_MODE so the employee only sees
 * data they already have access to. Contains no DML.
 */
public with sharing class KAN4_OrderLookupService {

    public class Input {
        @InvocableVariable(label='Customer Query' description='Customer name, account number or email' required=true)
        public String customerQuery;
        @InvocableVariable(label='Account Id' description='Account Id chosen from a candidate list; empty otherwise')
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Status') public String status;
        @InvocableVariable(label='Message') public String message;
        @InvocableVariable(label='Candidates') public String candidates;
        @InvocableVariable(label='Account Name') public String accountName;
        @InvocableVariable(label='Account Id') public String accountId;
        @InvocableVariable(label='Order Number') public String orderNumber;
        @InvocableVariable(label='Order Date') public String orderDate;
        @InvocableVariable(label='Order Status') public String orderStatus;
        @InvocableVariable(label='Total Amount') public String totalAmount;
        @InvocableVariable(label='Order URL') public String orderUrl;
    }

    @InvocableMethod(label='Lookup Latest Customer Order'
                     description='Finds a customer by name, account number or email and returns their most recent order (read-only).')
    public static List<Output> lookup(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            results.add(lookupOne(inp));
        }
        return results;
    }

    private static Output lookupOne(Input inp) {
        Output out = new Output();
        out.candidates = '';
        try {
            List<Account> accounts = resolveAccounts(inp);
            String q = inp.customerQuery == null ? '' : inp.customerQuery.trim();
            if (accounts.isEmpty()) {
                out.status = 'NOT_FOUND';
                out.message = 'I couldn\'t find a customer matching "' + q + '". Could you share more details, such as the account number or a contact email address?';
                return out;
            }
            if (accounts.size() > 1) {
                out.status = 'MULTIPLE_MATCHES';
                List<String> lines = new List<String>();
                Integer i = 1;
                for (Account a : accounts) {
                    lines.add(i + '. ' + a.Name
                        + ' (Account Number: ' + (a.AccountNumber == null ? 'n/a' : a.AccountNumber)
                        + ', City: ' + (a.BillingCity == null ? 'n/a' : a.BillingCity)
                        + ', Id: ' + a.Id + ')');
                    i++;
                }
                out.candidates = String.join(lines, '\n');
                out.message = 'More than one customer matches "' + q + '". Which one do you mean?\n' + out.candidates;
                return out;
            }

            Account acct = accounts[0];
            out.accountName = acct.Name;
            out.accountId = acct.Id;
            List<Order> orders = [
                SELECT Id, OrderNumber, EffectiveDate, Status, TotalAmount
                FROM Order
                WHERE AccountId = :acct.Id
                WITH USER_MODE
                ORDER BY EffectiveDate DESC, CreatedDate DESC
                LIMIT 1
            ];
            if (orders.isEmpty()) {
                out.status = 'NO_ORDERS';
                out.message = acct.Name + ' has no orders on record.';
                return out;
            }
            Order o = orders[0];
            out.status = 'FOUND';
            out.orderNumber = o.OrderNumber;
            out.orderDate = o.EffectiveDate == null ? 'n/a' : String.valueOf(o.EffectiveDate);
            out.orderStatus = o.Status;
            out.totalAmount = (o.TotalAmount == null ? '0.00' : o.TotalAmount.setScale(2).format())
                + ' ' + UserInfo.getDefaultCurrency();
            out.orderUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Order/' + o.Id + '/view';
            out.message = 'The most recent order for ' + acct.Name + ' is Order ' + o.OrderNumber
                + ', placed on ' + out.orderDate
                + ', status ' + o.Status
                + ', total ' + out.totalAmount
                + '. View it here: ' + out.orderUrl;
        } catch (Exception e) {
            // QueryException / SecurityException when the user lacks access
            out.status = 'ERROR';
            out.message = 'You don\'t have access to that information.';
        }
        return out;
    }

    private static List<Account> resolveAccounts(Input inp) {
        // 1. Explicit account chosen from a candidate list
        if (String.isNotBlank(inp.accountId)) {
            Id acctId;
            try { acctId = Id.valueOf(inp.accountId.trim()); } catch (Exception e) { acctId = null; }
            if (acctId != null && acctId.getSObjectType() == Account.SObjectType) {
                return [SELECT Id, Name, AccountNumber, BillingCity FROM Account WHERE Id = :acctId WITH USER_MODE LIMIT 1];
            }
        }
        String q = inp.customerQuery == null ? '' : inp.customerQuery.trim();
        if (String.isBlank(q)) {
            return new List<Account>();
        }
        // 2. Email lookup via Contact
        if (q.contains('@')) {
            Set<Id> acctIds = new Set<Id>();
            for (Contact c : [SELECT AccountId FROM Contact WHERE Email = :q AND AccountId != null WITH USER_MODE LIMIT 20]) {
                acctIds.add(c.AccountId);
            }
            if (acctIds.isEmpty()) {
                return new List<Account>();
            }
            return [SELECT Id, Name, AccountNumber, BillingCity FROM Account WHERE Id IN :acctIds WITH USER_MODE ORDER BY Name LIMIT 10];
        }
        // 3. Exact account number or name
        List<Account> exact = [
            SELECT Id, Name, AccountNumber, BillingCity FROM Account
            WHERE AccountNumber = :q OR Name = :q
            WITH USER_MODE ORDER BY Name, AccountNumber LIMIT 10
        ];
        if (!exact.isEmpty()) {
            return exact;
        }
        // 4. Partial name match
        String likeQ = '%' + q + '%';
        return [
            SELECT Id, Name, AccountNumber, BillingCity FROM Account
            WHERE Name LIKE :likeQ
            WITH USER_MODE ORDER BY Name, AccountNumber LIMIT 10
        ];
    }
}