#!/usr/bin/env python3
"""Write build/catalog.json: every runbook's metadata plus its playbook path.

The estate-ops-platform reads this to know which runbooks exist, what they need and how risky
they are, then runs them through Semaphore. Runbooks themselves never leave this repo.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    entries = []
    for meta_path in sorted((ROOT / "ansible/runbooks").glob("*/*/meta.yml")):
        meta = yaml.safe_load(meta_path.read_text(encoding="utf-8"))
        meta["playbook"] = (meta_path.parent / "runbook.yml").relative_to(ROOT).as_posix()
        entries.append(meta)
    try:
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        commit = None
    out = ROOT / "build/catalog.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(
        json.dumps(
            {"schema": "ops-foundation/catalog/v1", "commit": commit, "runbooks": entries}, indent=2, default=str
        )
        + "\n"
    )
    print(f"wrote {out.relative_to(ROOT)} with {len(entries)} runbooks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
