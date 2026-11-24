# af-demo: KAN-4 Order Lookup Assistant

An Agentforce **employee agent** that answers read-only questions about a customer's most recent order, for example *"What was the last order placed by Acme?"*. It returns the order number, date, status, total and a link to the record.

* Jira: [KAN-4](https://jainparvesh.atlassian.net/browse/KAN-4)
* Design: [docs/KAN-4-design.md](docs/KAN-4-design.md) ([Confluence](https://jainparvesh.atlassian.net/wiki/spaces/~5de06df53384720d18797897/pages/2621441/KAN-4+Design+Employee+Order+Lookup+Agent+Agent+Script))

## Contents

| Path | What it is |
|---|---|
| `force-app/main/default/aiAuthoringBundles/KAN4_Order_Lookup_Agent/` | Agent Script source (`.agent`): agent router, `order_lookup` and `off_topic` subagents |
| `force-app/main/default/aiAgents/`, `aiAgentDefinitionVersions/` | Published agent metadata (version 1), retrieved after publish |
| `force-app/main/default/classes/KAN4_OrderLookupService.cls` | Invocable Apex action: read-only, `with sharing`, all queries `WITH USER_MODE`, no DML |
| `force-app/main/default/classes/KAN4_OrderLookupServiceTest.cls` | 12 unit tests, 100% coverage (includes a restricted-user test) |
| `force-app/main/default/permissionsets/KAN4_Order_Lookup_Access.permissionset-meta.xml` | Agent access, Apex class access, read-only Account/Contact/Order |
| `scripts/apex/seed.apex` | Test data: 5 KAN4 customers, 7 orders, 2 products (activates the Standard Price Book) |
| `scripts/preview-send.sh` | Helper to send utterances to an agent preview session |

## Behaviour

| Scenario | Response |
|---|---|
| Single match with orders | Latest order: number, date, status, total, record link |
| Multiple customers match | Lists candidates and asks the user to choose |
| Customer has no orders | Says so clearly, without guessing |
| No customer matches | Asks for an account number or email |
| Write requests or off-topic questions | Politely declines; read-only |

The customer can be identified by account name (exact, then partial match), account number, or contact email.

## Deploy

```bash
# 1. Apex (the action target must exist before the agent is published)
sf project deploy start --source-dir force-app/main/default/classes -o <org> --test-level RunSpecifiedTests --tests KAN4_OrderLookupServiceTest

# 2. Optional test data
sf apex run --file scripts/apex/seed.apex -o <org>

# 3. Validate, publish and activate the agent
sf agent validate authoring-bundle --api-name KAN4_Order_Lookup_Agent -o <org>
sf agent publish authoring-bundle --api-name KAN4_Order_Lookup_Agent -o <org>
sf agent activate --api-name KAN4_Order_Lookup_Agent -o <org>

# 4. Access (after activation)
sf project deploy start --source-dir force-app/main/default/permissionsets -o <org>
sf org assign permset --name KAN4_Order_Lookup_Access -o <org>
```

Users with the permission set see **Order Lookup Assistant** in the Agentforce sidebar.
