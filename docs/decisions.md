# Decisions

Short records of choices that are not obvious from the code.

**Runbooks live only here.** The platform reads `build/catalog.json` and runs them through Semaphore;
it never keeps copies. One tested source, and an engineer can run the same runbook by hand.

**Decide is a separate, pure step.** All judgement sits in `tasks/decide.yml`, which reads facts and
parameters only. That makes every branch testable in CI without Windows, vCenter or a customer, and it is
the same seam the platform's agents use: they can propose parameters, but the runbook still decides
whether acting is safe.

**Escalate rather than guess.** Each runbook names the cases where the obvious fix is wrong (a stray SQL
log backup breaking the customer's restore chain, a snapshot left by a backup job, a spooler disabled for
PrintNightmare, an account locked by an old phone). Those escalate with a reason instead of acting.

**Dry run by default, approval by risk.** A forgotten flag can never change a customer system.

**Agentless first.** The edge node polls vCenter, SNMP, syslog and APIs. Agents go on servers only where
API data is not enough (SQL Server, event logs). Fewer moving parts per customer.

**One tenant id everywhere.** The same `tenant_id` names the repo folder, the NetBox tenant, the
OpenObserve organisation, the OpenBao path and every telemetry record. The guard checks it on every run.

**Same edge node on every platform.** One cloud-init for vSphere, Azure and AWS, so a customer's cloud
choice changes only the OpenTofu module, not what runs.

**Pinned tool versions.** Ansible, collections and images are pinned and the Semaphore runner image is
built from the same `requirements.txt` CI uses, so a runbook behaves the same in CI and on site.
