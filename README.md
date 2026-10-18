# ops-foundation

Configuration as code for our managed operations service: the runbooks engineers and agents run,
the edge node we place at each customer site, the telemetry it collects, and the glue to our service desk.
Everything here is open source or cheap, cloud-neutral, and the same for every customer.

The agentic platform (`estate-ops-platform`, separate repo) decides *what* to do. This repo holds *how*:
it reads `build/catalog.json` to learn which runbooks exist and runs them through Semaphore. Runbooks live
only here, so there is one tested copy of each.

## Layout

| Path | What it holds |
|---|---|
| `ansible/runbooks/<domain>/<name>/` | One runbook per folder: `meta.yml` (contract), `runbook.yml`, `tasks/` (gather, decide, act, verify), `tests/cases.yml` |
| `ansible/roles/` | `runbook_run` (the one way a runbook runs), `runbook_guard` (tenant, blast radius, approval), `runbook_evidence`, `graph_token` |
| `ansible/playbooks/` | Onboarding and edge node playbooks |
| `customers/<tenant_id>/` | Per-customer inventory, settings and edge node definitions. `_template/` to copy, `lab/` is fictitious |
| `edge/` | Edge node stack: OpenTelemetry Collector, Semaphore runner, Oxidized, OpenBao agent, optional Zabbix proxy; cloud-init |
| `tofu/modules/` | OpenTofu modules to build an edge node on vSphere, Azure or AWS from the same cloud-init |
| `observability/alerts/` | Tool-neutral alert specs, each linked to the runbook that answers it |
| `integrations/` | HaloPSA note writer (Thread syncs from HaloPSA) |
| `tools/` | Repo contract checks and the catalog builder |
| `docs/` | Runbook contract, onboarding checklist, integrations, decisions |

## Runbooks in this first slice

| Runbook | Risk | Approval | Answers |
|---|---|---|---|
| `sql/log-backup-shrink` | medium | required | SQL transaction log full |
| `windows/restart-spooler` | low | not required | Print spooler stopped or jobs stuck |
| `endpoint/clear-teams-cache` | low | not required | "Teams won't load" calls (Intune on-demand remediation) |
| `identity/unlock-account` | low | required (identity check) | Locked AD account |
| `vmware/expand-disk` | medium | required | Server volume almost full |

Every runbook is **dry run by default**, refuses to run against another customer's hosts, caps how many
hosts one run may touch, escalates anything it cannot prove safe, and prints one `RUNBOOK_EVIDENCE` JSON
line per host that becomes the note on the ticket. See [docs/runbook-contract.md](docs/runbook-contract.md).

## Running locally

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml -p ansible/collections
python -m pytest            # contract checks, guard tests, every runbook's decision cases
python tools/validate_repo.py
```

A real run (normally started by Semaphore):

```sh
ansible-playbook ansible/runbooks/windows/restart-spooler/runbook.yml \
  -i customers/lab/inventory -e rb_tenant=lab -e rb_targets=lab-prt01            # dry run
  # add -e rb_dry_run=false (and -e rb_approval_ref=<ticket> where approval is required) to act
```

## Secrets

None in this repo, ever. Credentials live in OpenBao under `secret/customers/<tenant_id>/...` and are read
at run time. CI runs gitleaks and a plaintext-secret check on every push.
