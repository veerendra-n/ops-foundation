import subprocess
import sys

from conftest import ROOT


def test_repo_contract():
    r = subprocess.run([sys.executable, "tools/validate_repo.py"], cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout


def test_catalog_builds():
    r = subprocess.run([sys.executable, "tools/build_catalog.py"], cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
