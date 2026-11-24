/**
 * KAN-1 Order Lookup Assistant - returns the most recent order for a customer account.
 * Read-only. Runs with sharing and in user mode so the agent only sees what the employee can see.
 */
public with sharing class OrderAgent_GetLastOrder {

    public class Input {
        @InvocableVariable(label='Account Id' description='Id of the selected customer account' required=true)
        public String accountId;
    }

    public class Output {
        @InvocableVariable(label='Found' description='True if an order was found, otherwise False')
        public String found;
        @InvocableVariable(label='Customer Name' description='Name of the customer account')
        public String customerName;
        @InvocableVariable(label='Order Number' description='Order number')
        public String orderNumber;
        @InvocableVariable(label='Order Date' description='Order start date (yyyy-MM-dd)')
        public String orderDate;
        @InvocableVariable(label='Status' description='Order status')
        public String status;
        @InvocableVariable(label='Total Amount' description='Order total amount with currency')
        public String totalAmount;
        @InvocableVariable(label='Order URL' description='Link to the order record')
        public String orderUrl;
        @InvocableVariable(label='Message' description='Summary of the result')
        public String message;
    }

    @InvocableMethod(label='Order Agent: Get Last Order' description='Returns the most recent order for a customer account (read-only)')
    public static List<Output> getLastOrder(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input inp : inputs) {
            results.add(getOne(inp == null ? null : inp.accountId));
        }
        return results;
    }

    private static Output getOne(String accountIdRaw) {
        Output out = new Output();
        out.found = 'False';
        out.customerName = '';
        out.orderNumber = '';
        out.orderDate = '';
        out.status = '';
        out.totalAmount = '';
        out.orderUrl = '';

        Id accId;
        try {
            accId = Id.valueOf(accountIdRaw == null ? '' : accountIdRaw.trim());
        } catch (Exception e) {
            out.message = 'A valid customer account Id is required.';
            return out;
        }

        List<Account> accts = [SELECT Id, Name FROM Account WHERE Id = :accId WITH USER_MODE LIMIT 1];
        if (accts.isEmpty()) {
            out.message = 'The customer account could not be found or you do not have access to it.';
            return out;
        }
        out.customerName = accts[0].Name;

        List<Order> orders = [SELECT Id, OrderNumber, EffectiveDate, Status, TotalAmount
                              FROM Order WHERE AccountId = :accId
                              WITH USER_MODE
                              ORDER BY EffectiveDate DESC, CreatedDate DESC LIMIT 1];
        if (orders.isEmpty()) {
            out.message = accts[0].Name + ' has no orders on file.';
            return out;
        }

        Order o = orders[0];
        out.found = 'True';
        out.orderNumber = o.OrderNumber;
        out.orderDate = o.EffectiveDate == null ? 'n/a' : String.valueOf(o.EffectiveDate);
        out.status = o.Status;
        Decimal amt = o.TotalAmount == null ? 0 : o.TotalAmount.setScale(2);
        out.totalAmount = UserInfo.getDefaultCurrency() + ' ' + amt.format();
        out.orderUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Order/' + o.Id + '/view';
        out.message = 'Most recent order for ' + accts[0].Name + ': ' + o.OrderNumber;
        return out;
    }
}