#!/usr/bin/env python3
"""Repository contract checks that linters cannot do. Exits non-zero with one line per problem.

Checks every runbook against docs/runbook-contract.md, every alert against the runbook catalog,
every customer directory against its tenant id, and YAML files for plaintext secrets.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
RUNBOOKS = ROOT / "ansible" / "runbooks"
REQUIRED_FILES = [
    "meta.yml",
    "runbook.yml",
    "tasks/gather.yml",
    "tasks/decide.yml",
    "tasks/act.yml",
    "tasks/verify.yml",
    "tests/cases.yml",
]
COMMON_PARAMS = {"rb_targets", "rb_tenant", "rb_dry_run", "rb_approval_ref", "rb_run_id"}
SECRET_KEY = re.compile(r"^\s*[\w.-]*(password|secret|token|api_key|apikey)[\w.-]*\s*:\s*(?P<v>.+)$", re.I)


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def runbook_dirs() -> list[Path]:
    return sorted(p.parent for p in RUNBOOKS.glob("*/*/meta.yml"))


def check_runbooks(errors: list[str]) -> dict[str, dict]:
    schema = json.loads((ROOT / "tools/schemas/runbook-meta.schema.json").read_text())
    validator = Draft202012Validator(schema)
    catalog = {}
    for d in runbook_dirs():
        rel = d.relative_to(RUNBOOKS).as_posix()
        for f in REQUIRED_FILES:
            if not (d / f).is_file():
                errors.append(f"{rel}: missing {f}")
        meta = load(d / "meta.yml")
        for e in validator.iter_errors(meta):
            errors.append(f"{rel}/meta.yml: {'/'.join(map(str, e.path)) or '(root)'}: {e.message}")
        if not isinstance(meta, dict):
            continue
        if meta.get("id") != rel:
            errors.append(f"{rel}/meta.yml: id '{meta.get('id')}' must equal its path '{rel}'")
        if meta.get("risk") != "low" and meta.get("approval") != "required":
            errors.append(f"{rel}/meta.yml: risk {meta.get('risk')} needs approval: required")

        play = load(d / "runbook.yml") if (d / "runbook.yml").is_file() else [{}]
        play_vars = (play[0] or {}).get("vars", {}) or {}
        if (play[0] or {}).get("hosts") != "{{ rb_targets }}":
            errors.append(f"{rel}/runbook.yml: hosts must be '{{{{ rb_targets }}}}' so every run names its targets")
        if "runbook_run" not in ((play[0] or {}).get("roles") or []):
            errors.append(f"{rel}/runbook.yml: must run the runbook_run role")
        for p in meta.get("params", []):
            if "default" in p and play_vars.get(p["name"]) != p["default"]:
                errors.append(
                    f"{rel}: default for {p['name']} differs between meta.yml ({p['default']!r}) "
                    f"and runbook.yml ({play_vars.get(p['name'])!r})"
                )

        cases = load(d / "tests/cases.yml") if (d / "tests/cases.yml").is_file() else []
        outcomes = set(meta.get("outcomes", []))
        seen = set()
        for c in cases or []:
            if c.get("expect") not in outcomes:
                errors.append(
                    f"{rel}/tests/cases.yml: case '{c.get('name')}' expects unknown outcome {c.get('expect')!r}"
                )
            seen.add(c.get("expect"))
            for k in c.get("params") or {}:
                if k not in {p["name"] for p in meta.get("params", [])}:
                    errors.append(f"{rel}/tests/cases.yml: case '{c.get('name')}' sets undeclared param {k}")
        for missing in sorted(outcomes - seen):
            errors.append(f"{rel}: no test case covers outcome '{missing}'")
        catalog[rel] = meta
    return catalog


def check_alerts(errors: list[str], catalog: dict[str, dict]) -> None:
    for f in sorted((ROOT / "observability/alerts").glob("*.yml")):
        a = load(f)
        if a.get("id") != f.stem:
            errors.append(f"{f.name}: id must equal file name")
        rb = catalog.get(a.get("runbook"))
        if not rb:
            errors.append(f"{f.name}: runbook {a.get('runbook')!r} does not exist")
            continue
        declared = {p["name"] for p in rb["params"]} | COMMON_PARAMS
        for k in a.get("runbook_params", {}) or {}:
            if k not in declared:
                errors.append(f"{f.name}: runbook_params {k} is not a parameter of {rb['id']}")
        if a["id"] not in rb.get("triggers", []):
            errors.append(f"{f.name}: {rb['id']} does not list {a['id']} in its triggers")


def check_customers(errors: list[str]) -> None:
    for d in sorted(p for p in (ROOT / "customers").iterdir() if p.is_dir() and p.name != "_template"):
        c = load(d / "customer.yml")
        if c.get("tenant_id") != d.name:
            errors.append(f"customers/{d.name}: tenant_id {c.get('tenant_id')!r} must equal the directory name")
        gv = d / "inventory/group_vars/all/main.yml"
        if gv.is_file() and load(gv).get("tenant_id") != d.name:
            errors.append(f"customers/{d.name}: inventory tenant_id must equal the directory name")
        if "TENANT_ID" in "".join(p.read_text() for p in d.rglob("*") if p.is_file()):
            errors.append(f"customers/{d.name}: template placeholder TENANT_ID left in place")


def check_secrets(errors: list[str]) -> None:
    for f in ROOT.rglob("*.y*ml"):
        if any(part in {".venv", ".git", "collections", "build", ".github"} for part in f.parts):
            continue
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            m = SECRET_KEY.match(line)
            if not m:
                continue
            key = line.split(":")[0].strip()
            if key.endswith(("_path", "_id", "_file", "_ref", "_name")):
                continue
            v = m.group("v").strip()
            if v.startswith(("{{", '"{{', "'{{", "${", "<%")) or v in {"", "|", ">-", "null", "~"} or v.startswith("#"):
                continue
            if v.lower() in {"true", "false"} or v.startswith(("[", "{")):
                continue
            errors.append(f"{f.relative_to(ROOT)}:{n}: value for '{key}' looks like a plaintext secret")


def main() -> int:
    errors: list[str] = []
    catalog = check_runbooks(errors)
    check_alerts(errors, catalog)
    check_customers(errors)
    check_secrets(errors)
    for e in errors:
        print(f"ERROR {e}")
    print(f"{len(catalog)} runbooks, {len(errors)} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
