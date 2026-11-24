# KAN-1 – Order Lookup Assistant (Agentforce Employee Agent)

Read-only Agentforce employee agent that answers "What was the last order placed by customer X?".

- Jira: https://jainparvesh.atlassian.net/browse/KAN-1
- Design: https://jainparvesh.atlassian.net/wiki/spaces/~5de06df53384720d18797897/pages/2228225/KAN-1+Design+Order+Lookup+Employee+Agent (copy in `docs/KAN-1-design.md`)

## Contents

| Path | Purpose |
|---|---|
| `force-app/main/default/classes/OrderAgent_FindCustomer.cls` | Invocable action – find customer by name, account number or contact email (with sharing, user mode) |
| `force-app/main/default/classes/OrderAgent_GetLastOrder.cls` | Invocable action – most recent order for an account (with sharing, user mode) |
| `force-app/main/default/classes/OrderAgent_Test.cls` | Unit tests (100% coverage of both actions) |
| `force-app/main/default/aiAuthoringBundles/Order_Lookup_Assistant/` | Agent Script definition (source of truth for the agent) |
| `force-app/main/default/aiAgents/`, `aiAgentDefinitionVersions/` | Compiled agent metadata retrieved after publish (v1) |
| `force-app/main/default/permissionsets/Order_Lookup_Agent_Access.permissionset-meta.xml` | Agent access, Apex class access, read-only Account/Contact/Order |
| `scripts/apex/seed.apex` | Test data for acceptance criterion 9 |

## Deployment order

1. Deploy the Apex classes and run `OrderAgent_Test`.
2. Validate, publish and activate the `Order_Lookup_Assistant` authoring bundle. Publishing does not activate the agent.
3. Deploy the `Order_Lookup_Agent_Access` permission set and assign it to employees.
4. Optional: run `scripts/apex/seed.apex` in a test org to load sample customers and orders.
