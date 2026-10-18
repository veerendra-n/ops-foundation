# Onboarding a customer

Target for customer 1: live mid November 2026, in **recommend and approve** mode: runbooks run dry by
default and act only with an engineer's approval. Steps marked *(customer)* need their IT team.

## 1. Paperwork and access *(customer)*
- [ ] Security sign-off for an outbound-only edge node per site and the service accounts below
- [ ] Least-privilege service accounts, stored in OpenBao under `secret/customers/<tenant_id>/`:
      WinRM (servers), delegated AD "unlock account" right, vCenter role limited to their VM folders
      with "change disk size", SNMPv3 read-only, network read-only SSH for Oxidized
- [ ] Entra app registration in their tenant (Graph: managed devices read and privileged operations,
      reports read) with admin consent; secret into OpenBao
- [ ] Who owns SQL log backups per database (their backup tool or SQL Agent job) for `sql/log-backup-shrink`

## 2. Repo and source of truth
- [ ] `cp -r customers/_template customers/<tenant_id>` and replace every `TENANT_ID`; fill `customer.yml`
- [ ] `ansible-playbook ansible/playbooks/onboard-netbox.yml -e customer=<tenant_id>` creates the tenant,
      sites, runbook tags, the `vm_uuid` field and the Oxidized export template
- [ ] Import devices and VMs into NetBox (vCenter and network discovery); tag hosts `rb-sql-servers`,
      `rb-print-servers`, `rb-ad-pdc`, `rb-vmware-guests`, network devices `oxidized`
- [ ] `python tools/validate_repo.py` passes

## 3. Edge node per site
- [ ] OpenBao: AppRole `edge` policy for this customer, secrets at `<secrets_path>/edge/<site>`
- [ ] `customers/<tenant_id>/tofu/main.tf`: pick the vSphere, Azure or AWS module; `tofu apply` with a
      freshly wrapped secret_id
- [ ] Collector health on :13133, data visible in the customer's OpenObserve organisation
- [ ] Semaphore runner registered and shown online for the customer's project
- [ ] VMs without `disk.EnableUUID=TRUE` listed and fixed in their next window (needed by `vmware/expand-disk`)

## 4. Service desk
- [ ] HaloPSA client and contract created; Thread connected to the customer's Teams
- [ ] Semaphore project per customer: inventory `customers/<tenant_id>/inventory`, one template per
      runbook from `build/catalog.json`, environment pulling secrets from OpenBao
- [ ] Teams cache remediation package uploaded to their Intune, id set in `customer_teams_remediation_id`

## 5. Prove it before go-live
- [ ] Each runbook dry-run once against a real host per type; evidence note lands on a test ticket
- [ ] One approved live run per runbook in an agreed window
- [ ] Alerts from `observability/alerts/` firing into the right ticket queue
