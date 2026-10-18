#!/usr/bin/env python3
"""Post runbook evidence to a HaloPSA ticket as a private note.

Reads Semaphore task output (a file or stdin), picks out the RUNBOOK_EVIDENCE lines the
runbook_evidence role prints, and adds one note per target to the ticket. Thread (our service
desk front end) syncs from HaloPSA, so engineers see the note there too.

Environment: HALO_URL (https://<instance>.halopsa.com), HALO_CLIENT_ID, HALO_CLIENT_SECRET,
optional HALO_TENANT for hosted instances. All come from OpenBao via the Semaphore environment.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections.abc import Iterable

MARKER = "RUNBOOK_EVIDENCE "
OUTCOME_TEXT = {
    "fixed": "Fixed and verified",
    "pending_device": "Fix queued; waiting for the device to report back",
    "dry_run": "Dry run only; nothing was changed",
    "no_action": "Checked; nothing needed",
    "escalated": "Not safe to fix automatically; needs an engineer",
    "failed": "Runbook failed",
}


def parse_evidence(lines: Iterable[str]) -> list[dict]:
    """Return every evidence record found in the task output, in order.

    Handles the default callback, which prints the line as a JSON string ("msg": "RUNBOOK_EVIDENCE {...}"),
    and plain output where the marker starts the payload directly.
    """
    decoder = json.JSONDecoder()
    records = []
    for line in lines:
        idx = line.find(MARKER)
        if idx < 0:
            continue
        text = line[idx:]
        if idx > 0 and line[idx - 1] == '"':
            try:
                text, _ = decoder.raw_decode(line, idx - 1)
            except json.JSONDecodeError:
                continue
        try:
            records.append(json.loads(text[len(MARKER) :]))
        except json.JSONDecodeError:
            continue
    return records


def format_note(ev: dict) -> str:
    """Plain-text note an engineer can read in a few seconds."""
    lines = [
        f"Runbook {ev['runbook']} v{ev['runbook_version']} on {ev['target']}",
        f"Outcome: {OUTCOME_TEXT.get(ev.get('outcome'), ev.get('outcome'))}",
        f"Why: {ev.get('decision', {}).get('reason', 'n/a')}",
    ]
    for act in ev.get("actions") or []:
        detail = ", ".join(f"{k}={v}" for k, v in act.items() if k != "action")
        lines.append(f"Did: {act.get('action')}" + (f" ({detail})" if detail else ""))
    if ev.get("error"):
        lines.append(f"Error: {ev['error']}")
    lines.append(f"Run {ev['run_id']}, approval {ev.get('approval_ref') or 'none'}, finished {ev['finished_at']}")
    return "\n".join(lines)


def get_token(session, base: str) -> str:
    data = {
        "grant_type": "client_credentials",
        "client_id": os.environ["HALO_CLIENT_ID"],
        "client_secret": os.environ["HALO_CLIENT_SECRET"],
        "scope": "all",
    }
    params = {"tenant": os.environ["HALO_TENANT"]} if os.environ.get("HALO_TENANT") else None
    r = session.post(f"{base}/auth/token", data=data, params=params, timeout=30)
    r.raise_for_status()
    return r.json()["access_token"]


def post_notes(ticket_id: int, records: list[dict]) -> None:
    import requests

    base = os.environ["HALO_URL"].rstrip("/")
    with requests.Session() as s:
        s.headers["Authorization"] = f"Bearer {get_token(s, base)}"
        body = [
            {"ticket_id": ticket_id, "note": format_note(ev), "outcome": "Automation", "hiddenfromuser": True}
            for ev in records
        ]
        r = s.post(f"{base}/api/Actions", json=body, timeout=30)
        r.raise_for_status()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--ticket", type=int, required=True, help="HaloPSA ticket id")
    ap.add_argument("--input", default="-", help="Semaphore task output file, default stdin")
    ap.add_argument("--dry-run", action="store_true", help="print the notes instead of posting")
    args = ap.parse_args(argv)

    if args.input == "-":
        records = parse_evidence(sys.stdin)
    else:
        with open(args.input, encoding="utf-8") as fh:
            records = parse_evidence(fh)
    if not records:
        print("no RUNBOOK_EVIDENCE lines found", file=sys.stderr)
        return 2
    if args.dry_run:
        for ev in records:
            print(format_note(ev), end="\n\n")
        return 0
    post_notes(args.ticket, records)
    print(f"posted {len(records)} note(s) to ticket {args.ticket}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
