/**
 * KAN-1 Order Lookup Assistant - finds customer accounts by name, account number or contact email.
 * Read-only. Runs with sharing and in user mode so the agent only sees what the employee can see.
 */
public with sharing class OrderAgent_FindCustomer {

    public class Input {
        @InvocableVariable(label='Customer Query' description='Customer name, account number or contact email' required=true)
        public String customerQuery;
    }

    public class Output {
        @InvocableVariable(label='Match Count' description='Number of matching customers (0-10)')
        public String matchCount;
        @InvocableVariable(label='Match List' description='Numbered list of matching customers with Id')
        public String matchList;
        @InvocableVariable(label='Account Id' description='Account Id when exactly one customer matches')
        public String accountId;
        @InvocableVariable(label='Message' description='Summary of the search result')
        public String message;
    }

    private static final Integer MAX_RESULTS = 10;

    @InvocableMethod(label='Order Agent: Find Customer' description='Finds customer accounts by name, account number or contact email (read-only)')
    public static List<Output> find(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            results.add(findOne(inp == null ? null : inp.customerQuery));
        }
        return results;
    }

    private static Output findOne(String rawQuery) {
        Output out = new Output();
        out.accountId = '';
        out.matchList = '';
        String q = rawQuery == null ? '' : rawQuery.trim();

        if (String.isBlank(q)) {
            out.matchCount = '0';
            out.message = 'No customer name, account number or email was provided.';
            return out;
        }

        List<Account> accounts;
        if (q.contains('@')) {
            Set<Id> accountIds = new Set<Id>();
            for (Contact c : [SELECT AccountId FROM Contact
                              WHERE Email = :q AND AccountId != null
                              WITH USER_MODE LIMIT 50]) {
                accountIds.add(c.AccountId);
            }
            accounts = [SELECT Id, Name, AccountNumber, BillingCity FROM Account
                        WHERE Id IN :accountIds
                        WITH USER_MODE ORDER BY Name LIMIT :MAX_RESULTS];
        } else {
            String escaped = q.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
            String likeTerm = '%' + escaped + '%';
            accounts = [SELECT Id, Name, AccountNumber, BillingCity FROM Account
                        WHERE AccountNumber = :q OR Name LIKE :likeTerm
                        WITH USER_MODE ORDER BY Name LIMIT :MAX_RESULTS];
        }

        out.matchCount = String.valueOf(accounts.size());
        if (accounts.isEmpty()) {
            out.message = 'No customer found matching "' + q + '".';
            return out;
        }

        List<String> lines = new List<String>();
        Integer i = 1;
        for (Account a : accounts) {
            lines.add(i + '. ' + a.Name
                + ' - Account #: ' + (String.isBlank(a.AccountNumber) ? 'n/a' : a.AccountNumber)
                + ' - City: ' + (String.isBlank(a.BillingCity) ? 'n/a' : a.BillingCity)
                + ' (Id: ' + a.Id + ')');
            i++;
        }
        out.matchList = String.join(lines, '\n');

        if (accounts.size() == 1) {
            out.accountId = accounts[0].Id;
            out.message = 'Found one customer: ' + accounts[0].Name + '.';
        } else {
            out.message = 'Found ' + accounts.size() + ' customers matching "' + q + '". Ask the user which one they mean.';
        }
        return out;
    }
}