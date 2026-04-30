import json
import os
from pathlib import Path
from models import WorkItem

# Local storage — items.json sits next to main.py
ITEMS_PATH = Path(__file__).parent / "items.json"
MANUAL_PATH = Path(__file__).parent.parent / "manual_items.yaml"
TOMBSTONE_PATH = Path(__file__).parent / "tombstone.json"


def _title_key(item: WorkItem) -> str:
    """Normalized title+source fingerprint for fuzzy dedup."""
    return f"{item.source}::{item.title.strip().lower()}"


def load_tombstone() -> set[str]:
    """IDs and title-fingerprints that must never re-appear."""
    if not TOMBSTONE_PATH.exists():
        return set()
    txt = TOMBSTONE_PATH.read_text().strip()
    return set(json.loads(txt)) if txt else set()


def add_to_tombstone(item: WorkItem) -> None:
    """Tombstone by both ID and title fingerprint so URL variants can't slip back in."""
    ids = load_tombstone()
    ids.add(item.id)
    ids.add(_title_key(item))
    TOMBSTONE_PATH.write_text(json.dumps(sorted(ids), indent=2))


def add_id_to_tombstone(item_id: str, title_key: str | None = None) -> None:
    ids = load_tombstone()
    ids.add(item_id)
    if title_key:
        ids.add(title_key)
    TOMBSTONE_PATH.write_text(json.dumps(sorted(ids), indent=2))


def load_items() -> list[WorkItem]:
    if not ITEMS_PATH.exists():
        return []
    with open(ITEMS_PATH) as f:
        data = json.load(f)
    return [WorkItem(**d) for d in data]


def save_items(items: list[WorkItem]) -> None:
    with open(ITEMS_PATH, "w") as f:
        json.dump([item.model_dump() for item in items], f, indent=2, default=str)


def load_manual_items() -> list[dict]:
    """Load hand-edited items from manual_items.yaml."""
    if not MANUAL_PATH.exists():
        return []
    try:
        import yaml
        with open(MANUAL_PATH) as f:
            data = yaml.safe_load(f) or {}
        return data.get("items") or []
    except ImportError:
        return []


def merge_with_existing(new_items: list[WorkItem], existing: list[WorkItem], tombstone: set[str] | None = None) -> list[WorkItem]:
    """
    Merge new items with existing, preserving human overrides.
    - Tombstoned items (by ID or title fingerprint) are permanently excluded
    - If an item exists and is human_confirmed → keep existing values
    - New items whose title+source matches a human_confirmed existing item → skip (same thing, different URL)
    - Items no longer in source are removed unless human_confirmed
    """
    if tombstone is None:
        tombstone = set()

    existing_map = {item.id: item for item in existing}
    # Secondary index: title fingerprint → existing human-confirmed item
    confirmed_title_map = {
        _title_key(item): item
        for item in existing
        if item.human_confirmed
    }

    new_map = {item.id: item for item in new_items}
    merged = []

    for item_id, new_item in new_map.items():
        # Block by exact ID
        if item_id in tombstone:
            continue
        # Block by title fingerprint
        if _title_key(new_item) in tombstone:
            continue

        existing_item = existing_map.get(item_id)
        if existing_item and existing_item.human_confirmed:
            # Preserve human overrides (bucket, flag, notes, context)
            # but always refresh live metadata from source
            existing_item.title = new_item.title
            existing_item.source_url = new_item.source_url
            existing_item.last_signal = new_item.last_signal
            # Only update due_date from source if not manually set by user
            if new_item.due_date:
                existing_item.due_date = new_item.due_date
            merged.append(existing_item)
        elif not existing_item and _title_key(new_item) in confirmed_title_map:
            # Same content, different ID (URL variant) — keep the confirmed version
            confirmed = confirmed_title_map[_title_key(new_item)]
            confirmed.last_signal = new_item.last_signal
            merged.append(confirmed)
        else:
            merged.append(new_item)

    # Keep human-confirmed items that no longer appear in source
    seen_ids = {i.id for i in merged}
    for item_id, existing_item in existing_map.items():
        if item_id in seen_ids:
            continue
        if item_id in tombstone or _title_key(existing_item) in tombstone:
            continue
        if existing_item.human_confirmed:
            merged.append(existing_item)

    return merged
