# KAN-1 Design – Order Lookup Employee Agent

| Item | Value |
|---|---|
| Jira story | KAN-1 – Create a agent for order data queries |
| Salesforce org | SF Org1 |
| Agent | Order Lookup Assistant (`Order_Lookup_Assistant`) |
| Agent type | Agentforce Employee Agent, built with Agent Script |
| Status | Design – ready for review |

## 1. Overview

Service and sales employees need quick answers about a customer's order history, for example "What was the last order placed by customer X?". Today they find the account and then sort through related orders by hand. This design describes a read-only Agentforce employee agent. It runs in the Salesforce sidebar and answers order questions in plain language.

### In scope

The agent finds a customer by name, account number or contact email. It returns the customer's most recent order. It handles the no-match, multiple-match and no-orders cases, and it declines off-topic and write requests.

### Out of scope (possible later additions)

Order line items, shipping status, "last N orders" and date-range questions.

## 2. Acceptance criteria traceability

| AC | Requirement | How the design meets it |
|---|---|---|
| 1 | Employee-facing agent in the sidebar | Employee agent type; access granted by permission set |
| 2 | Return order number, date, status, total and link | `OrderAgent_GetLastOrder` returns all five fields |
| 3 | Disambiguate duplicate customers | Agent Script branch when `matchCount` > 1: list the matches and ask the employee to pick one |
| 4 | No orders means say so, never guess | Branch when `found` = False with a fixed response |
| 5 | Customer not found means ask for more details | Branch when `matchCount` = 0: ask for an account number or email |
| 6 | Respect the user's data access | Apex uses `with sharing` and `WITH USER_MODE`; the agent runs as the signed-in user |
| 7 | Read-only | No DML in any action; write requests are declined in instructions |
| 8 | Decline off-topic questions | System instructions plus an `off_topic` topic |
| 9 | Tested with 5+ customers across all cases | Test data plan (section 6) and test cases (section 7) |

## 3. Solution architecture

```
Employee (Salesforce sidebar)
        │
        ▼
Order Lookup Assistant  (Agent Script, Employee Agent)
   ├─ start_agent entry ──► topic order_lookup   (default)
   │                    └─► topic off_topic      (non-order / write requests)
   │
   └─ topic order_lookup
        ├─ action find_customer   ─► apex://OrderAgent_FindCustomer
        └─ action get_last_order  ─► apex://OrderAgent_GetLastOrder
                                        │
                                        ▼
                         Account / Contact / Order  (user mode, with sharing)
```

### 3.1 Data model

These are standard objects only. No custom order object was found in the org.

| Object | Fields used |
|---|---|
| Account | Id, Name, AccountNumber, BillingCity |
| Contact | Email, AccountId (lookup by email) |
| Order | Id, OrderNumber, EffectiveDate, Status, TotalAmount, AccountId, CreatedDate |

### 3.2 Apex action: OrderAgent_FindCustomer

The class is `with sharing` and uses `@InvocableMethod`. All queries run `WITH USER_MODE`.

| Direction | Name | Type | Description |
|---|---|---|---|
| Input | customerQuery | String (required) | Customer name, account number or contact email |
| Output | matchCount | String | "0", "1" … up to "10" |
| Output | matchList | String | Numbered list: `1. Name – Acct# – City (Id)` |
| Output | accountId | String | Set only when exactly 1 match |
| Output | message | String | Human-readable summary |

How it works:

1. If the input contains "@", look up `Contact.Email = :q` and collect AccountIds.
2. Otherwise, match `Account.AccountNumber = :q` OR `Account.Name LIKE :('%' + q + '%')`.
3. De-duplicate the results, cap them at 10 and sort by Name.

### 3.3 Apex action: OrderAgent_GetLastOrder

The class is `with sharing` and uses `@InvocableMethod`. Queries run `WITH USER_MODE`.

| Direction | Name | Type | Description |
|---|---|---|---|
| Input | accountId | String (required) | Selected Account Id |
| Output | found | String | "True" or "False" |
| Output | orderNumber | String | Order.OrderNumber |
| Output | orderDate | String | EffectiveDate (yyyy-MM-dd) |
| Output | status | String | Order.Status |
| Output | totalAmount | String | Currency-formatted TotalAmount |
| Output | orderUrl | String | `<org domain>/lightning/r/Order/<Id>/view` |
| Output | message | String | Summary or "no orders" text |

The query is `SELECT … FROM Order WHERE AccountId = :id WITH USER_MODE ORDER BY EffectiveDate DESC, CreatedDate DESC LIMIT 1`.

All outputs are Strings, which avoids type-mapping issues in Agent Script.

### 3.4 Agent Script design

Config:

```
config:
  developer_name: "Order_Lookup_Assistant"
  agent_label: "Order Lookup Assistant"
  description: "Read-only employee assistant that finds a customer's most recent order"
  agent_type: "AgentforceEmployeeAgent"
```

No `default_agent_user` is set, because employee agents don't need one.

Variables (all mutable strings, default ""): `customer_query`, `match_count`, `match_list`, `account_id`, `order_summary`.

System instructions:

- You only help with customer order lookups.
- You never create, update or cancel records.
- Never guess order data. Only report what the actions return.

Deterministic flow in topic `order_lookup`:

| Condition | Agent behaviour |
|---|---|
| No customer given | Ask for a customer name, account number or email |
| After find_customer, `match_count == "0"` | "I couldn't find a customer matching X. Can you share an account number or contact email?" |
| `match_count` > 1 | Show `match_list` and ask the user to pick one, then set `account_id` to the chosen Id |
| `match_count == "1"` or the user has picked | Run `get_last_order` with `account_id` |
| `found == "False"` | "<Customer> has no orders on file." |
| `found == "True"` | Order number, date, status, total and record link |

Topic `off_topic`: politely declines non-order questions and any request to change data. It explains that the agent can look up a customer's most recent order.

### 3.5 Security and access

Permission set: `Order_Lookup_Agent_Access`

| Element | Value |
|---|---|
| agentAccesses | agent `Order_Lookup_Assistant`, type `EmployeeAgentUser`, agentType `BotDefinition` |
| classAccesses | OrderAgent_FindCustomer, OrderAgent_GetLastOrder |
| objectPermissions | Read only: Account, Contact, Order, GenAiPlanner |

Assign the permission set to employee users after the agent is activated.

Data visibility is enforced by user-mode queries plus sharing (AC 6). A user who can't see an order can't get it through the agent.

## 4. Build and deployment sequence

1. Develop the Apex classes and the test class `OrderAgent_Test` (target ≥ 85% coverage; no-match, single-match, multi-match, email match, no-orders and has-orders cases).
2. Deploy the Apex to the org. The action targets must exist before the agent is published.
3. Generate the Agent Script authoring bundle `Order_Lookup_Assistant` and replace the boilerplate with the design above.
4. Validate the bundle.
5. Publish the bundle.
6. Activate the agent. Publishing alone doesn't activate it.
7. Deploy and assign the `Order_Lookup_Agent_Access` permission set.
8. Run the preview tests with live actions (section 7).

## 5. Org discovery (current state)

| Item | Finding |
|---|---|
| Agent Script support | Available (AiAuthoringBundle, API 68.0) |
| Existing agents | None |
| Accounts | 4: Global Media, Acme, salesforce.com, Sample Account for Entitlements |
| Orders | 0 |
| Pricebook | Standard Price Book exists but is inactive; 1 product |

## 6. Test data plan (AC 9)

| # | Account | Orders | Purpose |
|---|---|---|---|
| 1 | Acme | 3 orders: 2026-08-15, 2026-09-20, 2026-10-30 | Normal case. Expect the newest (2026-10-30) |
| 2 | Global Media | 1 order: 2026-10-05 | Normal case, single order |
| 3 | salesforce.com | 0 | No-orders case |
| 4 | Northwind Traders (Sydney) – new | 1 order: 2026-09-01 | Duplicate-name case |
| 5 | Northwind Traders (Melbourne) – new | 1 order: 2026-10-12 | Duplicate-name case |
| 6 | "Zyxco Ltd" (does not exist) | – | Not-found case |

Setup steps:

1. Activate the Standard Price Book.
2. Create a standard price book entry for the existing product.
3. Create the orders with Status Draft and 1–2 order products each, so TotalAmount populates.
4. Add a Contact with an email on Acme to test email lookup.

## 7. Test cases

| # | Utterance | Expected result | AC |
|---|---|---|---|
| T1 | What was the last order placed by Acme? | 2026-10-30 Acme order with number, date, status, total and link | 2 |
| T2 | Last order for Global Media | Its single order with all fields | 2 |
| T3 | Last order for salesforce.com | "salesforce.com has no orders on file." | 4 |
| T4 | Last order for Northwind Traders | Lists both accounts and asks which one; answers after selection | 3 |
| T5 | Last order for Zyxco Ltd | Not found; asks for account number or email | 5 |
| T6 | Last order for the customer with email (Acme contact) | Acme's latest order | 2 |
| T7 | Cancel Acme's last order | Declines – read-only | 7 |
| T8 | What's the weather today? | Declines and explains its scope | 8 |
| T9 | Run as a user without Order read access | No order data returned | 6 |

## 8. Risks and open questions

| Risk / question | Mitigation |
|---|---|
| Partial-name LIKE search may return extra matches | Handled by the pick-one step; results capped at 10 |
| Agentforce sidebar not enabled for some users | Confirm Agentforce is enabled and the permission set is assigned |
| Are custom order objects used in production? | None found in this org; confirm with the business before building |
| Large accounts with many orders | LIMIT 1 query on indexed AccountId; no performance concern expected |
