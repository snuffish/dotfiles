#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["textual>=0.80"]
# ///
"""Clickable ADO overlay for a tmux display-popup: tabs by kind, list, markdown preview. Cache-first; fetches in the background."""
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import seen as seen_mod  # noqa: E402
from textual.app import App, ComposeResult  # noqa: E402
from textual.binding import Binding  # noqa: E402
from textual.containers import Horizontal, Vertical, VerticalScroll  # noqa: E402
from textual.widgets import Label, ListItem, ListView, Markdown, Static  # noqa: E402

HERE = os.path.dirname(os.path.realpath(__file__))
FETCH = os.environ.get("ADO_FETCH") or os.path.join(HERE, "ado-fetch")
STALE_SECONDS = 600
TAB_LABELS = {"comment": "✎", "vote": "✓", "workitem": "#", "all": "All"}
TAB_ORDER = ["comment", "vote", "workitem", "all"]


def open_url(url):
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    subprocess.Popen([opener, url], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


class Tab(Static):
    def __init__(self, key, **kwargs):
        super().__init__("", classes="tab", **kwargs)
        self.key = key


class Row(ListItem):
    def __init__(self, event, text, is_seen):
        super().__init__(Label(text, markup=False), classes="seen" if is_seen else "")
        self.ado_event = event


class Overlay(App):
    CSS = """
    Screen { background: #1e1e2e; color: #cdd6f4; }
    #tabs { height: 1; background: #313244; }
    .tab { width: auto; padding: 0 1; }
    .tab.active { background: #fab387; color: #1e1e2e; text-style: bold; }
    #status { width: 1fr; color: #a6adc8; padding: 0 1; }
    #close { color: #f38ba8; }
    #body { height: 1fr; }
    #list { height: 5; background: #1e1e2e; }
    #list > ListItem.-highlight { background: #45475a; }
    ListItem.seen Label { color: #6c7086; }
    #preview { height: 1fr; border-top: solid #45475a; padding: 0 1; }
    """
    BINDINGS = [
        Binding("escape,q", "close", "close"),
        Binding("enter", "open", "open", priority=True),
        Binding("j", "move(1)", "down"),
        Binding("k", "move(-1)", "up"),
        Binding("1", "tab('comment')", "✎"),
        Binding("2", "tab('vote')", "✓"),
        Binding("3", "tab('workitem')", "#"),
        Binding("4", "tab('all')", "All"),
        Binding("tab,right", "cycle_tab(1)", "next tab", priority=True),
        Binding("shift+tab,left", "cycle_tab(-1)", "prev tab", priority=True),
        Binding("r", "refresh_data", "refresh"),
        Binding("m", "mark_seen", "mark seen"),
    ]

    def __init__(self):
        super().__init__()
        self.directory = seen_mod.cache_dir()
        self.events, self.seen = [], {"baseline": "", "ids": []}
        self.tab = None
        self.proc = None
        self.updating = False
        self.shown_id = None
        self.highlighted_at = 0.0

    def compose(self) -> ComposeResult:
        with Horizontal(id="tabs"):
            for key in TAB_ORDER:
                yield Tab(key, id=f"tab-{key}")
            yield Static("", id="status")
            yield Static("⟳", id="refresh", classes="tab")
            yield Static("✕", id="close", classes="tab")
        with Vertical(id="body"):
            yield ListView(id="list")
            yield VerticalScroll(Markdown("", id="md"), id="preview")

    async def on_mount(self):
        self.load()
        self.tab = seen_mod.first_tab(self.events, self.seen, self.now())
        await self.render_all()
        if self.fetch_running() or self.is_stale():
            self.start_fetch()
        self.set_interval(0.5, self.check_fetch)

    def now(self):
        return datetime.now(timezone.utc)

    # data ---------------------------------------------------------------
    def load(self):
        self.events = seen_mod.load_events(self.directory)
        self.seen = seen_mod.load_seen(self.directory, self.now())

    def is_stale(self):
        try:
            return time.time() - os.path.getmtime(os.path.join(self.directory, "state")) > STALE_SECONDS
        except OSError:
            return True

    def fetch_running(self):
        return (self.proc is not None and self.proc.poll() is None) or os.path.isdir(os.path.join(self.directory, "fetch.lock"))

    def start_fetch(self):
        if not self.fetch_running():
            self.proc = subprocess.Popen([FETCH], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        self.updating = True
        self.query_one("#status", Static).update("updating…")

    async def check_fetch(self):
        if self.updating and not self.fetch_running():
            self.updating = False
            self.query_one("#status", Static).update("")
            self.load()
            await self.render_all()

    def save_seen(self):
        seen_mod.save_seen(self.directory, self.seen)
        seen_mod.write_badge(self.directory, self.events, self.seen, self.now())

    # view ---------------------------------------------------------------
    async def render_all(self):
        counts = seen_mod.counts(self.events, self.seen, self.now())
        for key in TAB_ORDER:
            tab = self.query_one(f"#tab-{key}", Tab)
            tab.update(f"{TAB_LABELS[key]} {counts[key]}" if key != "all" else "All")
            tab.set_class(key == self.tab, "active")
        await self.rebuild_list()

    async def rebuild_list(self):
        view = self.query_one("#list", ListView)
        now = self.now()
        events = seen_mod.tab_events(self.tab, self.events, self.seen, now)
        keep = self.shown_id
        width = max(24, (view.size.width or 60) - 2)
        rows = []
        for event in events:
            age = seen_mod.age_text(event["time"], now)
            left = seen_mod.row_left(event, width - len(age) - 1)
            text = left.ljust(width - len(age)) + age
            rows.append(Row(event, text, not seen_mod.is_unseen(event, self.seen, now)))
        await view.clear()
        await view.extend(rows)
        index = next((i for i, row in enumerate(rows) if row.ado_event["id"] == keep), 0)
        if rows:
            view.index = index
        else:
            self.shown_id = None
            self.query_one("#md", Markdown).update("_Nothing unseen here._" if self.tab != "all" else "_Nothing in the last 7 days._")

    def current_event(self):
        item = self.query_one("#list", ListView).highlighted_child
        return item.ado_event if item is not None else None

    def on_resize(self, event):
        if self.tab is not None:
            self.call_after_refresh(self.rebuild_list)

    def on_list_view_highlighted(self, message):
        self.highlighted_at = time.monotonic()
        if message.item is not None:
            event = message.item.ado_event
            self.shown_id = event["id"]
            self.query_one("#md", Markdown).update(seen_mod.preview_markdown(event, self.now()))

    def on_list_view_selected(self, message):
        # A click on a row arrives as Highlighted then Selected: the first click only previews, a click on the shown row opens it.
        if time.monotonic() - self.highlighted_at > 0.05:
            self.action_open()

    async def on_click(self, event):
        widget = event.widget
        if isinstance(widget, Tab):
            await self.action_tab(widget.key)
        elif getattr(widget, "id", None) == "refresh":
            self.action_refresh_data()
        elif getattr(widget, "id", None) == "close":
            self.exit()

    # actions ------------------------------------------------------------
    def action_close(self):
        self.exit()

    def action_move(self, step):
        view = self.query_one("#list", ListView)
        view.action_cursor_down() if step > 0 else view.action_cursor_up()

    async def action_tab(self, key):
        self.tab = key
        self.shown_id = None
        await self.render_all()

    async def action_cycle_tab(self, step):
        i = TAB_ORDER.index(self.tab) if self.tab in TAB_ORDER else 0
        await self.action_tab(TAB_ORDER[(i + step) % len(TAB_ORDER)])

    def action_open(self):
        event = self.current_event()
        if event is None:
            return
        open_url(event["url"])
        seen_mod.mark_group(self.seen, self.events, event)
        self.save_seen()
        self.exit()

    def action_refresh_data(self):
        self.start_fetch()

    async def action_mark_seen(self):
        now = self.now()
        pending = seen_mod.unseen(seen_mod.tab_events(self.tab, self.events, self.seen, now), self.seen, now)
        seen_mod.mark_events(self.seen, pending)
        self.save_seen()
        await self.render_all()


if __name__ == "__main__":
    Overlay().run()
