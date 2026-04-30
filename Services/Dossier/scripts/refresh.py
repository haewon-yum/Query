#!/usr/bin/env python3
"""
Refresh the Dossier for a given account.
Usage:
  python scripts/refresh.py                    # refresh Netmarble (default)
  python scripts/refresh.py --account nexon    # future accounts

Runs: Slack ingest → Gong ingest → normalize → summarize → store
"""
import argparse
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import config
from ingest import slack as slack_ingest
from ingest import gong as gong_ingest
import normalize
from store import gcs


def refresh(account: str = config.NETMARBLE_ACCOUNT) -> None:
    print(f"\n{'='*60}")
    print(f"Dossier refresh — account: {account}")
    print(f"{'='*60}\n")

    # 1. Ingest
    print("[1/3] Ingesting Slack...")
    slack_data = slack_ingest.pull_all_netmarble_channels()

    print("\n[2/3] Ingesting Gong...")
    gong_calls = gong_ingest.pull_netmarble_calls()

    # 3. Normalize + summarize (Claude API called inside normalize.py)
    print("\n[3/3] Normalizing + summarizing (Claude API)...")
    events = normalize.normalize_all(slack_data, gong_calls, account)

    # 4. Store
    print(f"\n[4/4] Storing {len(events)} events...")
    gcs.write_events(events, account)

    print(f"\nDone. {len(events)} events written for {account}.")
    counts = {}
    for e in events:
        counts[e["source"]] = counts.get(e["source"], 0) + 1
    for src, n in counts.items():
        print(f"  {src}: {n}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--account", default=config.NETMARBLE_ACCOUNT)
    args = parser.parse_args()
    refresh(args.account)
