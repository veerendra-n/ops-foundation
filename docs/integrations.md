# Integrations

| System | Role | How this repo talks to it | State |
|---|---|---|---|
| Semaphore | Runs runbooks, holds per-customer projects, inventories, approvals | Remote runner on each edge node (`edge/compose`), outbound to our Semaphore server | Runner image defined; project-as-code sync is next |
| OpenBao | All secrets | `community.hashi_vault` lookups in runbooks; OpenBao agent renders edge node secrets | Paths and AppRole flow defined; policies are next |
| OpenObserve | Logs, metrics, traces, alerts; one organisation per customer | OTLP/HTTP from the edge collector | Collector config validated in CI; alert specs written, renderer is next |
| NetBox | Inventory source of truth; one tenant per customer | `netbox.netbox.nb_inventory`, `onboard-netbox.yml` | Ready |
| Oxidized | Network config backups | On the edge node, device list from a NetBox export template | Ready to test on a lab switch |
| HaloPSA | Ticket record, SLA clocks, billing | `integrations/halopsa/post_evidence.py` posts evidence as a private note | Parser tested; posting needs a sandbox instance to confirm |
| Thread | Service desk front end in Teams | Syncs from HaloPSA; nothing to build here | — |
| Intune (Graph) | Laptops in M365 shops | On-demand remediation (`endpoint/clear-teams-cache`) | Uses the Graph beta endpoint; confirm in the customer tenant |
| Level | Servers' patching and laptops outside Intune | Same scripts imported into Level | **Open:** Level's public API for running a script on demand is not confirmed, so Level-managed laptops are escalated for now |
| Zabbix | Hardware controllers and Dell storage only | Optional `hardware` profile on the edge node (active proxy) | Off unless a site needs it |

## Assumptions to confirm in the lab

These were written from documentation, not yet run against real systems:

- OpenObserve OTLP endpoint `/api/<org>/` with `stream-name` header and the stream names in the alert specs
- OTel `sqlserver` receiver metric `sqlserver.transaction_log.usage` and attribute `sqlserver.database.name`
- HaloPSA `POST /auth/token` and `POST /api/Actions` payload
- Semaphore runner `SEMAPHORE_WEB_ROOT` variable name
- Windows disk serial equals the VMDK UUID when `disk.EnableUUID=TRUE`
