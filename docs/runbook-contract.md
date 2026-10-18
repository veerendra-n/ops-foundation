# Runbook contract

Every runbook follows the same shape so that engineers, the platform's agents and the tests can treat
them alike. `tools/validate_repo.py` enforces the parts a linter cannot.

## Files

```
ansible/runbooks/<domain>/<name>/
  meta.yml          what it does, risk, approval, parameters, outcomes (schema: tools/schemas/runbook-meta.schema.json)
  runbook.yml       hosts "{{ rb_targets }}", parameter defaults (must equal meta.yml), role runbook_run
  tasks/gather.yml  read-only; sets rb_facts
  tasks/decide.yml  pure: reads rb_facts and parameters only; sets rb_decision {action, reason}
  tasks/act.yml     changes state; sets rb_actions
  tasks/verify.yml  reads again; sets rb_after and asserts the fix held (or sets rb_pending)
  tests/cases.yml   fixture facts -> expected action; every outcome in meta.yml needs a case
```

## How a run goes (`roles/runbook_run`)

1. **Guard** (`roles/runbook_guard`): loads `meta.yml`; refuses if `rb_tenant` differs from the host's
   `tenant_id`, if more hosts are targeted than `max_targets`, if a required parameter is missing, or if a
   live run of an approval-required runbook has no valid `rb_approval_ref`.
2. **Gather** facts from the target, read-only.
3. **Decide** an action. `none` and `escalate` stop here. Escalation is a normal, good outcome: the reason
   says what an engineer should look at.
4. **Act** and **verify**, only when `rb_dry_run=false`.
5. **Evidence** is always printed, even on failure.

## Parameters every run takes

| Variable | Meaning |
|---|---|
| `rb_tenant` | Customer the run is for. Must match the inventory. Required. |
| `rb_targets` | Host or group to run against. Required; there is no default group. |
| `rb_dry_run` | Defaults to `true`. Set `false` to act. |
| `rb_approval_ref` | Ticket or approval id. Required for live runs when `approval: required`. |
| `rb_run_id` | Id from the caller (Semaphore task or platform case), echoed in evidence. |

## Outcomes

`dry_run`, `no_action`, `escalated`, `fixed`, `pending_device` (fix queued on a device that reports back
later, e.g. Intune), `failed`.

## Evidence line

One line per host: `RUNBOOK_EVIDENCE {json}` with schema `ops-foundation/evidence/v1`: runbook, version,
run_id, tenant, target, dry_run, approval_ref, started_at, finished_at, before (rb_facts), decision,
actions, after, outcome, error. `integrations/halopsa/post_evidence.py` turns it into a ticket note; the
platform stores it in its case ledger.

## Risk and approval

| Risk | Meaning | Approval |
|---|---|---|
| low | Reversible, one host, no data touched | optional per runbook |
| medium | Changes capacity or service state in a way that is hard to undo | required |
| high | Could cause an outage or data loss | required, and not run by agents in this phase |

## Adding a runbook

Copy the closest existing folder, change `meta.yml` first, write the cases in `tests/cases.yml` before
`decide.yml`, then `python -m pytest`. Keep decisions in `decide.yml` so they stay testable without a target.
