"""Seen state and badge counts for the tmux ADO overlay (stdlib only).

Cache layout in $ADO_CACHE (default ~/.cache/tmux-ado/): events.json, seen.json, badge, state, fetch.lock.
An event is unseen until its thread is opened or marked, it is older than the baseline, or it leaves the 7-day window.
"""
import json
import os
import sys
import tempfile
from datetime import datetime, timedelta, timezone

WINDOW = timedelta(days=7)
TABS = (("comment", "✎"), ("vote", "✓"), ("workitem", "#"))


def cache_dir():
    path = os.environ.get("ADO_CACHE") or os.path.expanduser("~/.cache/tmux-ado")
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


def parse_time(text):
    return datetime.strptime(text[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)


def iso(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def write_atomic(path, text):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    with os.fdopen(fd, "w") as handle:
        handle.write(text)
    os.replace(tmp, path)


def read_json(path, default):
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return default


def load_events(directory):
    return read_json(os.path.join(directory, "events.json"), [])


def load_seen(directory, now):
    """seen.json as {"baseline": iso, "ids": [...]}; the first call sets baseline = now so old events never flood in."""
    path = os.path.join(directory, "seen.json")
    seen = read_json(path, None)
    if not isinstance(seen, dict) or "baseline" not in seen:
        seen = {"baseline": iso(now), "ids": []}
        write_atomic(path, json.dumps(seen))
    return seen


def save_seen(directory, seen):
    write_atomic(os.path.join(directory, "seen.json"), json.dumps(seen))


def group(event):
    """Events of one PR thread (or one work item) are seen together: opening the browser shows them all."""
    return f"{event['ref']}:{event.get('thread') or ''}"


def in_window(event, now):
    return now - parse_time(event["time"]) <= WINDOW


def is_unseen(event, seen, now):
    return (
        in_window(event, now)
        and parse_time(event["time"]) > parse_time(seen["baseline"])
        and event["id"] not in seen["ids"]
    )


def unseen(events, seen, now):
    return [event for event in events if is_unseen(event, seen, now)]


def counts(events, seen, now):
    pending = unseen(events, seen, now)
    return {kind: sum(1 for event in pending if event["kind"] == kind) for kind, _ in TABS}


def badge_body(tab_counts):
    """'✎ 2 ✓ 1 # 3' with the zero counts left out; empty when nothing is unseen."""
    return " ".join(f"{icon} {tab_counts[kind]}" for kind, icon in TABS if tab_counts[kind])


def mark_events(seen, events):
    ids = set(seen["ids"])
    ids.update(event["id"] for event in events)
    seen["ids"] = sorted(ids)
    return seen


def mark_group(seen, all_events, event):
    key = group(event)
    return mark_events(seen, [other for other in all_events if group(other) == key])


def prune(seen, events):
    """Drop ids of events that left the window so seen.json does not grow forever."""
    live = {event["id"] for event in events}
    seen["ids"] = sorted(set(seen["ids"]) & live)
    return seen


def newest_first(events):
    return sorted(events, key=lambda event: event["time"], reverse=True)


def tab_events(tab, events, seen, now):
    """Kind tabs list unseen events only (counts match the badge); 'all' lists the 7-day window, seen ones included."""
    if tab == "all":
        return newest_first([event for event in events if in_window(event, now)])
    return newest_first([event for event in unseen(events, seen, now) if event["kind"] == tab])


def first_tab(events, seen, now):
    """The overlay opens on the first non-empty tab in ✎ → ✓ → # order, else All."""
    for kind, _ in TABS:
        if tab_events(kind, events, seen, now):
            return kind
    return "all"


def age_text(when, now):
    seconds = max(0, int((now - parse_time(when)).total_seconds()))
    if seconds >= 86400:
        return f"{seconds // 86400}d"
    if seconds >= 3600:
        return f"{seconds // 3600}h"
    return f"{max(1, seconds // 60)}m"


def one_line(text):
    return " ".join((text or "").split())


def cut(text, width):
    return text if len(text) <= width else text[: max(0, width - 1)] + "…"


def row_left(event, width):
    """`!PR title · who “text…”` cut to width cells; the title gives way first, down to half the row.

    The age is right-aligned by the caller."""
    body = one_line(event["text"])
    if event["kind"] == "vote":
        body = body.removeprefix(event["author"]).strip()  # "Grace voted 10" → "voted 10"
    action = f"{event['author']} “{body}”" if event["kind"] == "comment" else f"{event['author']} {body}"
    head, sep = f"{event['ref']} ", " · "
    title = one_line(event.get("title"))
    room = width - len(head) - len(sep)
    title_room = min(len(title), max(room // 2, room - len(action)))
    if title_room < 4:
        return cut(head + action, width)
    return cut(f"{head}{cut(title, title_room)}{sep}{action}", width)


def preview_markdown(event, now):
    return f"### {event['ref']} {event['title']}\n\n**{event['author']}** · {age_text(event['time'], now)} ago\n\n{event['text']}"


def write_badge(directory, events, seen, now):
    write_atomic(os.path.join(directory, "badge"), badge_body(counts(events, seen, now)))


def refresh_badge(directory, now=None):
    now = now or datetime.now(timezone.utc)
    write_badge(directory, load_events(directory), load_seen(directory, now), now)


if __name__ == "__main__":
    if sys.argv[1:] == ["badge"]:
        refresh_badge(cache_dir())
    else:
        sys.exit("usage: seen.py badge")
