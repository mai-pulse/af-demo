# KAN-4 Design: Employee Order Lookup Agent (Agent Script)

* **Jira:** [KAN-4](https://jainparvesh.atlassian.net/browse/KAN-4)
* **Confluence:** [Design page](https://jainparvesh.atlassian.net/wiki/spaces/~5de06df53384720d18797897/pages/2621441/KAN-4+Design+Employee+Order+Lookup+Agent+Agent+Script)
* **Build approach:** Agentforce Agent Script (AiAuthoringBundle), employee agent

> Implementation note: the generator in recent tooling uses `subagent` / `@subagent.X` in place of `topic` / `@topic.X`. The deployed `.agent` file in `force-app/` uses the current syntax.

## 1. Story summary

Service and sales employees ask in plain language, for example "What was the last order placed by Acme?". The agent returns the most recent Order with its number, date, status, total and a record link. It is read-only, respects the user's existing access, and declines questions that aren't about orders.

## 2. What the org check found

| Check | Result | Impact on the design |
|---|---|---|
| `AiAuthoringBundle` metadata type | Supported | Agent Script path is viable |
| Existing agents (BotDefinition) | 0 | No naming conflicts |
| Custom order objects | None (only Shoe__c, TestLocation__c and similar) | Use standard **Account + Order** (answers the story's open question) |
| Order records | **0** | Test data must be seeded (AC9) |
| Accounts | 4 (Global Media, Acme, salesforce.com, Sample Account for Entitlements) | Reuse Acme where useful and add test accounts |
| Standard Price Book | Exists but **inactive**; 0 price book entries; 1 active product | Activate the price book and create products and entries so `TotalAmount` (a roll-up of order items) is non-zero |
| Order.Status picklist | Draft, Activated | Seed a mix of both |
| Existing order Apex classes | None | New service class |
| Agent tooling | Available (v2.159.7) | Generate, validate, publish, preview and activate are all supported |

## 3. Architecture

```
Employee (Lightning sidebar, Agentforce panel)
   └─ KAN4_Order_Lookup_Agent  (AgentforceEmployeeAgent, runs as the logged-in user)
        start_agent topic_selector
          ├─ order_lookup topic ──► apex://KAN4_OrderLookupService  (read-only, WITH USER_MODE)
          └─ off_topic topic (polite decline plus a description of what it can do)
```

**Why this shape:**
- **Employee agent:** runs as the logged-in user and inherits their permissions. No agent user is needed (AC1, AC6).
- **One Apex action:** handles the full decision tree deterministically: resolve the customer, then disambiguate, report not found or no orders, or return the latest order. This keeps answers accurate and prevents guessing (AC2–AC5).
- **Apex runs `with sharing` and queries use `WITH USER_MODE`:** enforces sharing, object security and field security (AC6).
- **No DML in the class, and the agent has no write actions:** a read-only guarantee (AC7).
- **`off_topic` topic plus system instructions:** decline anything that isn't an order question (AC8).

## 4. Component specifications

### 4.1 Apex: `KAN4_OrderLookupService` (invocable)

`public with sharing class`, `@InvocableMethod(label='Lookup Latest Customer Order')`

**Input** (all String):

| Field | Required | Purpose |
|---|---|---|
| `customerQuery` | Yes | Customer name, account number, or email, as typed by the employee |
| `accountId` | No | Set on a follow-up call after the employee picks from multiple matches |

**Output** (all String, per the docs' type-mapping guidance):

| Field | Description |
|---|---|
| `status` | `FOUND` / `NO_ORDERS` / `MULTIPLE_MATCHES` / `NOT_FOUND` / `ERROR` |
| `message` | Ready-to-display, human-readable answer |
| `accountName`, `accountId` | The resolved customer |
| `orderNumber`, `orderDate`, `orderStatus`, `totalAmount`, `orderUrl` | Latest order details |
| `candidates` | Numbered list (Name, Account Number, City, Id) when `MULTIPLE_MATCHES` |

**Resolution logic:**
1. If `accountId` is provided and valid (prefix 001): use it directly.
2. If `customerQuery` contains `@`: match `Contact.Email` and collect the distinct AccountIds.
3. Otherwise, match on `Account.AccountNumber = :q` OR `Account.Name = :q` (exact). If nothing matches, fall back to `Name LIKE %q%` (LIMIT 10).
4. 0 accounts → `NOT_FOUND`. The message asks for an account number or email (AC5).
5. More than 1 account → `MULTIPLE_MATCHES` with the candidate list. The message asks the employee to choose (AC3).
6. Exactly 1 account → `SELECT Id, OrderNumber, EffectiveDate, Status, TotalAmount FROM Order WHERE AccountId = :id WITH USER_MODE ORDER BY EffectiveDate DESC, CreatedDate DESC LIMIT 1`
   - None → `NO_ORDERS`: "<Account> has no orders on record." (AC4)
   - Found → `FOUND`, with the link `URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Order/' + Id + '/view'` and the amount formatted with the currency (AC2).
7. All SOQL uses `WITH USER_MODE`. Any `QueryException` or `SecurityException` returns `ERROR` with the message "You don't have access to that information." (AC6). The class contains no DML (AC7).

### 4.2 Apex test class: `KAN4_OrderLookupServiceTest`

At least 90% coverage. Cases: found (latest of 2 orders is chosen), no orders, multiple matches, follow-up with `accountId`, not found, email match, account-number match, and a restricted-user run (`System.runAs` with a minimal-access user returns no data).

### 4.3 Agent: `KAN4_Order_Lookup_Agent`

The bundle folder must match `developer_name` exactly. Scaffold it with the generator, then replace the boilerplate.

```yaml
config:
  developer_name: "KAN4_Order_Lookup_Agent"
  agent_label: "Order Lookup Assistant"
  description: "Internal assistant that answers read-only questions about a customer's most recent order"
  agent_type: "AgentforceEmployeeAgent"

system:
  messages:
    welcome: "Hi! I can look up a customer's most recent order. Just ask, e.g. 'What was the last order placed by Acme?'"
    error: "Sorry, something went wrong looking that up. Please try again."
  instructions: "You are an internal order lookup assistant for service and sales employees. You only answer questions about customer orders using the lookup action. Never invent order data. You cannot create, update or delete records. Be concise."

variables:
  lookup_status: mutable string = ""
    description: "Status from the last lookup"
  lookup_message: mutable string = ""
    description: "Answer text from the last lookup"
  candidate_list: mutable string = ""
    description: "Candidate accounts when multiple matched"

start_agent topic_selector:
  description: "Route order questions to lookup; everything else to off_topic"
  reasoning:
    instructions: |
      Route requests:
      - Questions about a customer's orders, last/latest/recent order → order_lookup
      - Anything else (weather, creating/updating records, general chat) → off_topic
    actions:
      go_orders: @utils.transition to @topic.order_lookup
        description: "User asks about a customer's orders"
      go_off_topic: @utils.transition to @topic.off_topic
        description: "Request is not about customer orders"

topic order_lookup:
  description: "Find the most recent order for a customer by name, account number or email"
  actions:
    lookup_latest_order:
      description: "Looks up the customer and returns their most recent order"
      inputs:
        customerQuery: string
          description: "Customer name, account number or email from the user"
        accountId: string
          description: "Account Id chosen by the user from a candidate list; empty otherwise"
      outputs:
        status: string
          description: "FOUND, NO_ORDERS, MULTIPLE_MATCHES, NOT_FOUND or ERROR"
        message: string
          description: "Answer to show the user"
        candidates: string
          description: "Numbered candidate accounts when multiple match"
      target: "apex://KAN4_OrderLookupService"
  reasoning:
    instructions: ->
      | Help the employee find a customer's most recent order. Always call {!@actions.lookup_latest_order}; never guess.
      | If no customer was named, ask for a customer name, account number or email.
      if @variables.lookup_status == "FOUND":
        | Present this exactly, including the order link: {!@variables.lookup_message}
      if @variables.lookup_status == "NO_ORDERS":
        | Tell the user clearly: {!@variables.lookup_message}. Do not suggest or invent orders.
      if @variables.lookup_status == "MULTIPLE_MATCHES":
        | Several customers matched. Show this list and ask which one they mean: {!@variables.candidate_list}
        | When they choose, call the lookup again with the chosen account's Id as accountId.
      if @variables.lookup_status == "NOT_FOUND":
        | {!@variables.lookup_message} Ask for an account number or email address.
      if @variables.lookup_status == "ERROR":
        | {!@variables.lookup_message}
    actions:
      lookup: @actions.lookup_latest_order
        with customerQuery = ...
        with accountId = ...
        set @variables.lookup_status = @outputs.status
        set @variables.lookup_message = @outputs.message
        set @variables.candidate_list = @outputs.candidates
      go_off_topic: @utils.transition to @topic.off_topic
        description: "User moves to a non-order request"

topic off_topic:
  description: "Politely decline requests that are not about customer orders"
  reasoning:
    instructions: |
      Politely explain you can only help with looking up a customer's most recent order
      (order number, date, status, total and link) and that you cannot create, change or delete records.
      Offer an example question.
    actions:
      go_orders: @utils.transition to @topic.order_lookup
        description: "User asks an order question"
```

Syntax rules to follow (from the docs): use the same 2-space indentation throughout, capitalised booleans, no nested `if`, both `inputs:` and `outputs:` blocks, I/O names that exactly match the Apex `@InvocableVariable` names, and no `default_agent_user`. If the validator rejects the multiple `with` lines on one invocation, collapse them into one line: `with customerQuery=..., accountId=...`.

### 4.4 Permission set: `KAN4_Order_Lookup_Access`

- `agentAccesses` comes **first**, using the verified form `<agentName>KAN4_Order_Lookup_Agent</agentName><enabled>true</enabled>`. If the deploy rejects it, fall back to `<agent>…</agent><agentAccessType>EmployeeAgentUser</agentAccessType><agentType>BotDefinition</agentType><enabled>true</enabled>`.
- `classAccesses`: `KAN4_OrderLookupService`
- `objectPermissions`: Read only on Account and Order; Read on GenAiPlanner. No create, edit, delete, view-all or modify-all.
- Deploy it **after** the agent is activated, then assign it to the running user and to the intended service and sales users.

### 4.5 Test data (AC9: at least 5 customers)

1. Activate the Standard Price Book. Create 2 products (for example "Widget Pro" $250 and "Service Plan" $99) and their standard PricebookEntries.

| # | Account (AccountNumber) | Scenario | Orders |
|---|---|---|---|
| 1 | **KAN4 Northwind Traders** (KAN4-1001) | Normal | 3 orders on different dates; the latest is Activated, about $599 |
| 2 | **KAN4 Contoso Ltd** (KAN4-1002) | Normal, single order | 1 Draft order |
| 3 | **KAN4 Fabrikam** (KAN4-1003) | No orders | 0 |
| 4 | **KAN4 Blue Yonder** (KAN4-2001, Sydney) | Duplicate name | 1 order |
| 5 | **KAN4 Blue Yonder** (KAN4-2002, Melbourne) | Duplicate name | 2 orders |
| — | "Zzyzx Industries" (does not exist) | Not found | — |

Each order uses `Pricebook2Id` = standard, `EffectiveDate`, `Status=Draft`, and 1–2 OrderItems. To activate an order, update `Status=Activated` after adding its items. Prefix all records with `KAN4` so they're easy to clean up. Add a Contact with email `buyer@northwind.example` on account 1 to test email lookup.

## 5. Build sequence

1. Create the project in `/workspace/Atlas/kan4-order-agent` (`sf project generate`), with source API version 66.0 or higher.
2. Seed the test data (§4.5).
3. Write and deploy both Apex classes and run the tests (90% coverage or higher).
4. Generate the authoring bundle: `sf agent generate authoring-bundle --no-spec --name "Order Lookup Assistant" --api-name KAN4_Order_Lookup_Agent -o salesforce-4qfx4y`. Replace the `.agent` content with §4.3.
5. Validate: `sf agent validate authoring-bundle --api-name KAN4_Order_Lookup_Agent -o salesforce-4qfx4y --json`
6. Preview with live actions before publishing: `sf agent preview start --authoring-bundle KAN4_Order_Lookup_Agent --use-live-actions -o salesforce-4qfx4y --json`. Run the test script (§6).
7. Publish: `sf agent publish authoring-bundle --api-name KAN4_Order_Lookup_Agent -o salesforce-4qfx4y --json`. Verify the new BotVersion.
8. Activate: `sf agent activate --api-name KAN4_Order_Lookup_Agent -o salesforce-4qfx4y`
9. Deploy the permission set and assign it to the running user.
10. Run the test script again against the published agent (`preview start --api-name …`). Optionally open the Agentforce panel in the browser to show the result.
11. Post a Jira comment on KAN-4 summarising the build and test results. Transition the issue only if the user asks.
12. Record the outcome in a report artifact.

## 6. Acceptance test script

| AC | Utterance | Expected |
|---|---|---|
| 2 | "What was the last order placed by KAN4 Northwind Traders?" | Latest order: number, date, Activated, ~$599, link |
| 2 | "Last order for account KAN4-1002" | Contoso Draft order details |
| 2 | "Latest order for buyer@northwind.example" | Northwind's latest order |
| 4 | "Last order for KAN4 Fabrikam?" | Clearly says there are no orders, with no guessing |
| 3 | "Last order by KAN4 Blue Yonder" → "the Melbourne one" | Asks the user to choose, then returns KAN4-2002's latest order |
| 5 | "Last order placed by Zzyzx Industries" | Says the customer couldn't be found and asks for an account number or email |
| 7 | "Cancel Northwind's last order" | Declines; says it is read-only |
| 8 | "What's the weather in Sydney?" | Politely declines and explains what it can help with |
| 6 | Apex `runAs` test with a restricted user | No data returned (the class enforces user mode) |
| 1 | Agentforce panel for the assigned user | Agent is visible in the sidebar |

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Einstein generative AI or Agentforce not fully enabled. Publish fails with a `globalConfiguration` null error | Validate early (step 5). If it fails, ask the user to enable Agentforce or Einstein in Setup |
| The CLI validates but the server compile fails | Use the Builder assistant: "List all current compilation errors" |
| `agentAccesses` schema differences | Two XML variants documented (§4.4) |
| Orphaned BotVersion after a failed publish | Republish under a new `developer_name` (for example `KAN4_Order_Lookup_Agent_v2`) |
| Credit use | Each lookup is one Apex action, about 20 credits; routing is free |

## 8. Out of scope (later additions noted in the story)

Order line items, shipping status, and "last N orders" or date-range questions. The design allows for these: add outputs or a second action in `order_lookup` later without restructuring.
