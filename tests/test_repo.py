import json
import subprocess
import sys

from conftest import ROOT


def test_repo_contract():
    r = subprocess.run([sys.executable, "tools/validate_repo.py"], cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout


def test_catalog_builds():
    r = subprocess.run([sys.executable, "tools/build_catalog.py"], cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_catalog_includes_alerts_linked_to_runbooks():
    subprocess.run([sys.executable, "tools/build_catalog.py"], cwd=ROOT, check=True, capture_output=True)
    cat = json.loads((ROOT / "build/catalog.json").read_text())
    ids = {r["id"] for r in cat["runbooks"]}
    assert len(cat["alerts"]) == len(list((ROOT / "observability/alerts").glob("*.yml")))
    assert all(a["runbook"] in ids for a in cat["alerts"])
