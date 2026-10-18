import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
ANSIBLE = ROOT / "ansible"


def run_playbook(playbook: str, extra: dict | None = None) -> subprocess.CompletedProcess:
    cmd = ["ansible-playbook", playbook, "-i", "localhost,"]
    for k, v in (extra or {}).items():
        cmd += ["-e", f"{k}={v}"]
    env = dict(
        os.environ,
        ANSIBLE_CONFIG=str(ROOT / "ansible.cfg"),
        ANSIBLE_NOCOLOR="1",
        ANSIBLE_LOCALHOST_WARNING="false",
        ANSIBLE_INVENTORY_UNPARSED_WARNING="false",
    )
    return subprocess.run(cmd, cwd=ANSIBLE, env=env, capture_output=True, text=True)


@pytest.fixture
def playbook():
    return run_playbook
