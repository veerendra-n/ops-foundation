"""The guard refuses unsafe runs; evidence comes out in the shape the HaloPSA note expects."""

import sys

from conftest import ROOT, run_playbook

sys.path.insert(0, str(ROOT / "integrations/halopsa"))
from post_evidence import format_note, parse_evidence  # noqa: E402

PB = "tests/guard_and_evidence.yml"


def test_dry_run_by_default_and_evidence_parses():
    r = run_playbook(PB, {"rb_tenant": "lab"})
    assert r.returncode == 0, r.stdout[-3000:]
    [ev] = parse_evidence(r.stdout.splitlines())
    assert ev["dry_run"] is True
    assert ev["tenant"] == "lab"
    assert ev["runbook"] == "sql/log-backup-shrink"
    assert ev["outcome"] == "dry_run"
    note = format_note(ev)
    assert "Dry run only" in note and "log_backup" in note


def test_refuses_other_tenant():
    r = run_playbook(PB, {"rb_tenant": "someone-else"})
    assert r.returncode != 0
    assert "Refusing to run across customers" in r.stdout


def test_refuses_missing_tenant():
    r = run_playbook(PB)
    assert r.returncode != 0


def test_live_run_needs_approval():
    r = run_playbook(PB, {"rb_tenant": "lab", "rb_dry_run": "false"})
    assert r.returncode != 0
    assert "needs an approval reference" in r.stdout


def test_live_run_with_approval():
    r = run_playbook(PB, {"rb_tenant": "lab", "rb_dry_run": "false", "rb_approval_ref": "HALO-10423"})
    assert r.returncode == 0, r.stdout[-3000:]
    [ev] = parse_evidence(r.stdout.splitlines())
    assert ev["dry_run"] is False and ev["approval_ref"] == "HALO-10423"


def test_rejects_odd_approval_ref():
    r = run_playbook(PB, {"rb_tenant": "lab", "rb_dry_run": "false", "rb_approval_ref": "x;rm -rf"})
    assert r.returncode != 0


def test_low_risk_runbook_runs_live_without_approval():
    r = run_playbook(PB, {"rb_tenant": "lab", "rb_dry_run": "false", "rb_under_test": "windows/restart-spooler"})
    assert r.returncode == 0, r.stdout[-3000:]


def test_missing_required_param():
    r = run_playbook(PB, {"rb_tenant": "lab", "rb_database": ""})
    assert r.returncode != 0
    assert "Missing required parameter rb_database" in r.stdout


def test_evidence_survives_backslashes_and_quotes():
    r = run_playbook(PB, {"rb_tenant": "lab", "rb_backup_path": 'E:\\SQL\\Log "x"'})
    assert r.returncode == 0, r.stdout[-3000:]
    assert len(parse_evidence(r.stdout.splitlines())) == 1
