"""Tests for the adopr.sh badge subcommand and the activity rows it shares a parser with.

Run: python3 -m unittest utils/test_adopr_badge.py
"""

import json
import os
import re
import subprocess
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "adopr.sh"
ME = "me@example.com"
STYLE = re.compile(r"#\[[^\]]*\]")


def iso(delta_seconds, fraction="1234567"):
    """ADO-style timestamp (7 fractional digits) delta_seconds from now."""
    t = datetime.now(timezone.utc) + timedelta(seconds=delta_seconds)
    return t.strftime("%Y-%m-%dT%H:%M:%S") + f".{fraction}Z"


def comment(when, who="alice@example.com", text="Please rename", kind="text"):
    return {
        "publishedDate": when,
        "commentType": kind,
        "author": {"displayName": who.split("@")[0].title(), "uniqueName": who},
        "content": text,
        "isDeleted": False,
    }


def thread(thread_id, comments, file_path=None):
    t = {"id": thread_id, "comments": comments}
    if file_path:
        t["threadContext"] = {"filePath": file_path}
    return t


def item(item_id, changed, by="alice@example.com", mention=False, assigned=False):
    return {
        "id": item_id, "type": "Task", "state": "Active", "title": f"Item {item_id}",
        "changed": changed, "by": by.split("@")[0].title(), "mine": by == ME,
        "assigned": assigned, "mention": mention,
        "url": f"https://dev.azure.com/org/PRIIS/_workitems/edit/{item_id}",
    }

# Rows captured from adopr.sh before the entries jq was shared with the badge (age column left out)
B, END = "\x1b[1m", "\x1b[0m"
URL = "https://dev.azure.com/org/PRIIS/_git/repo/pullrequest/101?discussionId="
WI = "https://dev.azure.com/org/PRIIS/_workitems/edit/"
GOLDEN_ROWS = [
    [f"{B}#12{END}", "\x1b[34mtask\x1b[0m", "\x1b[35mAlice\x1b[0m", "[Active] Item 12 · touched", WI + "12", "wi:12"],
    [f"{B}#11{END}", "\x1b[34mtask\x1b[0m", "\x1b[36mMe\x1b[0m", "[Active] Item 11 · assigned", WI + "11", "wi:11"],
    [f"{B}#10{END}", "\x1b[34mtask\x1b[0m", "\x1b[35mAlice\x1b[0m", "[Active] Item 10 · @", WI + "10", "wi:10"],
    [f"{B}101{END}", "\x1b[90mstatus\x1b[0m", "\x1b[35mAlice\x1b[0m", "Alice joined as a reviewer", URL + "3", "101:3"],
    [f"{B}101{END}", "\x1b[90mvote\x1b[0m", "\x1b[35mAlice\x1b[0m", "Alice voted 10", URL + "2", "101:2"],
    [f"{B}101{END}", "\x1b[33mcomment\x1b[0m", "\x1b[36mMe\x1b[0m", "Done", URL + "1", "101:1"],
    [f"{B}101{END}", "\x1b[33mcomment\x1b[0m", "\x1b[35mAlice\x1b[0m", "Please rename", URL + "1", "101:1"],
]


class AdoprCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        self.cache = root / "cache"
        (self.cache / "threads").mkdir(parents=True)
        self.home = root / "home"
        (self.home / ".azure").mkdir(parents=True)
        (self.home / ".azure" / "azureProfile.json").write_text(
            json.dumps({"subscriptions": [{"isDefault": True, "user": {"name": ME}}]})
        )
        self.wi = self.cache / "workitems.json"
        self.prs = self.cache / "prs.json"
        self.work = root / "work"
        self.work.mkdir()

    def env(self):
        return {
            **os.environ, "HOME": str(self.home), "ADOPR_CACHE": str(self.cache),
            "ADOPR_WI": str(self.wi), "ADOPR_PRS": str(self.prs), "ADOPR_DIR": str(self.work),
        }

    def write_threads(self, *prs):
        """prs: (pr_id, [thread, ...]). Also writes the PR list and the cached thread files."""
        listing = []
        for pr_id, threads in prs:
            listing.append({"id": pr_id, "url": f"https://dev.azure.com/org/PRIIS/_git/repo/pullrequest/{pr_id}"})
            (self.cache / "threads" / f"{pr_id}.json").write_text(json.dumps({"id": pr_id, "threads": threads}))
        self.prs.write_text(json.dumps(listing))
        self.write_activity(*prs)

    def write_activity(self, *prs):
        (self.cache / "activity.json").write_text(
            json.dumps([{"id": pr_id, "threads": threads} for pr_id, threads in prs])
        )

    def write_items(self, *items):
        self.wi.write_text(json.dumps({"items": list(items)}))

    def write_seen(self, epoch):
        (self.cache / "seen").write_text(str(int(epoch)))

    def run_script(self, *args):
        return subprocess.run(
            ["bash", str(SCRIPT), *args], env=self.env(), capture_output=True, text=True, timeout=60
        )

    def badge(self):
        result = self.run_script("badge")
        self.assertEqual(result.returncode, 0, result.stderr)
        text = (self.cache / "badge").read_text()
        return STYLE.sub("", text).strip()


def now():
    return datetime.now(timezone.utc).timestamp()


class BadgeCounts(AdoprCase):
    def test_counts_only_others_actions(self):
        self.write_threads((1, [thread(1, [comment(iso(-60), who=ME), comment(iso(-60))])]))
        self.write_seen(now() - 3600)
        self.assertEqual(self.badge(), "ADO ✎ 1")

    def test_each_kind_has_its_own_count(self):
        self.write_threads((1, [
            thread(1, [comment(iso(-60)), comment(iso(-50))]),
            thread(2, [comment(iso(-40), text="Alice voted 10", kind="system")]),
            thread(3, [comment(iso(-30), text="Alice joined as a reviewer", kind="system")]),
            thread(4, [comment(iso(-20), text="Policy status has been updated", kind="system")]),
        ]))
        self.write_items(
            item(10, iso(-60), mention=True),
            item(11, iso(-60), assigned=True),
            item(12, iso(-60)),
            item(13, iso(-60), by=ME, mention=True),
        )
        self.write_seen(now() - 3600)
        self.assertEqual(self.badge(), "ADO ✎ 2 ✓ 2 # 2")

    def test_seen_hides_older_entries(self):
        self.write_threads((1, [thread(1, [comment(iso(-7200)), comment(iso(-60))])]))
        self.write_items(item(10, iso(-7200), mention=True))
        self.write_seen(now() - 3600)
        self.assertEqual(self.badge(), "ADO ✎ 1")

    def test_all_zero_writes_an_empty_file(self):
        self.write_threads((1, [thread(1, [comment(iso(-7200))])]))
        self.write_seen(now() - 3600)
        self.assertEqual(self.badge(), "")
        self.assertEqual((self.cache / "badge").read_text(), "")

    def test_fractional_seconds_compare_by_whole_second(self):
        seen = now() - 600
        self.write_threads((1, [thread(1, [comment(iso(-605, "9999999")), comment(iso(-595, "0000001"))])]))
        self.write_seen(seen)
        self.assertEqual(self.badge(), "ADO ✎ 1")

    def test_missing_seen_counts_the_last_day_only(self):
        self.write_threads((1, [thread(1, [comment(iso(-2 * 86400)), comment(iso(-3600))])]))
        self.assertEqual(self.badge(), "ADO ✎ 1")

    def test_missing_caches_give_an_empty_badge(self):
        (self.cache / "activity.json").unlink(missing_ok=True)
        self.assertEqual(self.badge(), "")


class ActivityRows(AdoprCase):
    FIXTURE_DAYS = 400

    def fixture(self):
        d = lambda minutes: iso(-self.FIXTURE_DAYS * 86400 + minutes * 60)
        self.write_threads(
            (101, [
                thread(1, [comment(d(1), text="Please rename"), comment(d(2), who=ME, text="Done")], "/a.cs"),
                thread(2, [comment(d(3), text="Alice voted 10", kind="system"),
                           comment(d(4), text="Policy status has been updated", kind="system")]),
                thread(3, [comment(d(5), text="Alice joined as a reviewer", kind="system")]),
            ]),
        )
        self.write_items(item(10, d(6), mention=True), item(11, d(7), by=ME, assigned=True), item(12, d(8)))

    def rows(self):
        result = self.run_script("activity")
        self.assertEqual(result.returncode, 0, result.stderr)
        # Column 5 is the age, which moves with the clock
        return [line.split("\t")[:4] + line.split("\t")[5:] for line in result.stdout.splitlines()]

    def test_rows_match_the_golden_output(self):
        self.fixture()
        self.assertEqual(self.rows(), GOLDEN_ROWS)

    def test_activity_persists_cache_and_clears_the_badge(self):
        self.fixture()
        self.write_seen(now() - 86400 * (self.FIXTURE_DAYS + 1))
        self.assertEqual(self.badge(), "ADO ✎ 1 ✓ 2 # 1")
        self.rows()
        self.assertEqual(self.badge(), "")
        self.assertTrue((self.cache / "seen").read_text().strip().isdigit())


class Poll(AdoprCase):
    def stub_az(self, body):
        bindir = self.cache.parent / "bin"
        bindir.mkdir(exist_ok=True)
        stub = bindir / "az"
        stub.write_text(f"#!/bin/sh\n{body}\n")
        stub.chmod(0o755)
        return {**self.env(), "PATH": f"{bindir}:{os.environ['PATH']}"}

    def poll(self, env):
        return subprocess.run(["bash", str(SCRIPT), "poll"], env=env, capture_output=True, text=True, timeout=60)

    def test_failing_az_leaves_a_grey_error_badge_and_no_lock(self):
        result = self.poll(self.stub_az("echo 'login expired' >&2; exit 1"))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(STYLE.sub("", (self.cache / "badge").read_text()).strip(), "ADO !")
        self.assertFalse((self.cache / "poll.lock").exists())

    def test_held_lock_exits_at_once_without_touching_the_badge(self):
        (self.cache / "poll.lock").mkdir()
        (self.cache / "badge").write_text("keep")
        result = self.poll(self.stub_az("exit 1"))
        self.assertEqual(result.returncode, 0)
        self.assertEqual((self.cache / "badge").read_text(), "keep")
        self.assertTrue((self.cache / "poll.lock").exists())

    def test_stale_lock_is_taken_over(self):
        lock = self.cache / "poll.lock"
        lock.mkdir()
        old = now() - 3600
        os.utime(lock, (old, old))
        result = self.poll(self.stub_az("exit 1"))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(STYLE.sub("", (self.cache / "badge").read_text()).strip(), "ADO !")


class AgentRender(AdoprCase):
    def render(self):
        result = self.run_script("agent", "render")
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_render_fills_every_placeholder(self):
        out = self.render()
        self.assertNotRegex(out, r"@(ADOPR|PATH|HOME)@")
        self.assertIn(str(SCRIPT), out)
        self.assertIn("poll", out)
        self.assertRegex(out, r"(?s)(StartInterval.*600|OnUnitActiveSec=10min)")

    @unittest.skipUnless(os.uname().sysname == "Darwin", "plutil is macOS only")
    def test_rendered_plist_lints(self):
        plist = self.cache.parent / "rendered.plist"
        plist.write_text(self.render())
        result = subprocess.run(["plutil", "-lint", str(plist)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unknown_agent_verb_is_refused(self):
        self.assertNotEqual(self.run_script("agent", "bogus").returncode, 0)


if __name__ == "__main__":
    unittest.main()
