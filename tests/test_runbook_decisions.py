"""Runs every runbook's decision step against its fixture cases (ansible/tests/decide.yml)."""

import shutil
from pathlib import Path

import pytest
import yaml
from conftest import ANSIBLE, run_playbook

RUNBOOKS = sorted(p.parent for p in (ANSIBLE / "runbooks").glob("*/*/meta.yml"))


@pytest.mark.parametrize("rb", RUNBOOKS, ids=lambda p: p.relative_to(ANSIBLE / "runbooks").as_posix())
def test_decisions(rb: Path):
    r = run_playbook("tests/decide.yml", {"rb_dir": rb.relative_to(ANSIBLE).as_posix()})
    assert r.returncode == 0, r.stdout[-3000:] + r.stderr[-2000:]


def test_harness_fails_on_wrong_expectation(tmp_path):
    """A case with the wrong expected outcome must fail, or the suite proves nothing."""
    src = ANSIBLE / "runbooks/windows/restart-spooler"
    dst = ANSIBLE / "runbooks/zz-test/broken"
    try:
        shutil.copytree(src, dst)
        cases = yaml.safe_load((dst / "tests/cases.yml").read_text())
        cases[0]["expect"] = "none"
        (dst / "tests/cases.yml").write_text(yaml.safe_dump(cases))
        r = run_playbook("tests/decide.yml", {"rb_dir": "runbooks/zz-test/broken"})
        assert r.returncode != 0
        assert "expected none" in r.stdout
    finally:
        shutil.rmtree(dst.parent, ignore_errors=True)
