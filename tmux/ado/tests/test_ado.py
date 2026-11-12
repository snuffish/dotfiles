import importlib.machinery
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import unittest
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ADO = os.path.dirname(HERE)
sys.path.insert(0, ADO)
import seen  # noqa: E402

loader = importlib.machinery.SourceFileLoader("ado_fetch", os.path.join(ADO, "ado-fetch"))
spec = importlib.util.spec_from_loader("ado_fetch", loader)
fetch = importlib.util.module_from_spec(spec)
loader.exec_module(fetch)

NOW = datetime(2026, 11, 12, 12, 0, tzinfo=timezone.utc)


def fixture(name):
    with open(os.path.join(HERE, "fixtures", name)) as handle:
        return json.load(handle)


def fake_az(args):
    if args[:2] == ["repos", "pr"]:
        return fixture("prs.json") if "--creator" in args else []
    if args[0] == "devops":
        return fixture("threads.json")
    if args[0] == "boards":
        if "RecentMentions" in args[args.index("--wiql") + 1] and "OR" not in args[args.index("--wiql") + 1]:
            return []
        return fixture("workitems.json")
    raise AssertionError(args)


def read(directory, name):
    with open(os.path.join(directory, name)) as handle:
        return handle.read()


class TempCache(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)
        os.environ["ADO_PROJECTS"] = "PRIIS"
        os.environ["ADO_ORG"] = ""


class Normalise(unittest.TestCase):
    pr = {"id": 100, "title": "Add feature", "base": "dev.azure.com/org", "project": "PRIIS", "repo": "Repo"}

    def events(self):
        return fetch.normalise_threads(self.pr, fixture("threads.json")["value"], "me@example.com", NOW)

    def test_drops_mine_deleted_system_and_old(self):
        texts = [(e["kind"], e["text"]) for e in self.events()]
        self.assertEqual(texts, [("comment", "Please rename this"), ("vote", "Grace voted Approved")])

    def test_event_shape(self):
        event = self.events()[0]
        self.assertEqual(event["id"], "pr100-t5-c1")
        self.assertEqual(event["ref"], "!100")
        self.assertEqual(event["time"], "2026-11-12T08:00:00Z")
        self.assertTrue(event["url"].endswith("/PRIIS/_git/Repo/pullrequest/100?discussionId=5"))

    def test_workitems_need_assignment_or_mention(self):
        items = [dict(i, web="u") for i in fixture("workitems.json")]
        events = fetch.normalise_workitems(items, "me@example.com", NOW, set())
        self.assertEqual([e["ref"] for e in events], ["#42"])
        events = fetch.normalise_workitems(items, "me@example.com", NOW, {43})
        self.assertEqual([e["ref"] for e in events], ["#42", "#43"])

    def test_web_base(self):
        self.assertEqual(fetch.web_base("https://org.visualstudio.com/g/_apis/x"), "dev.azure.com/org")
        self.assertEqual(fetch.web_base("https://dev.azure.com/org/g/_apis/x"), "dev.azure.com/org")


class Seen(unittest.TestCase):
    events = [
        {"id": "a", "kind": "comment", "ref": "!1", "thread": "5", "time": "2026-11-12T08:00:00Z"},
        {"id": "b", "kind": "comment", "ref": "!1", "thread": "5", "time": "2026-11-12T09:00:00Z"},
        {"id": "c", "kind": "vote", "ref": "!1", "thread": "6", "time": "2026-11-12T10:00:00Z"},
        {"id": "d", "kind": "workitem", "ref": "#9", "thread": "", "time": "2026-11-05T10:00:00Z"},
        {"id": "e", "kind": "comment", "ref": "!2", "thread": "1", "time": "2026-11-01T10:00:00Z"},
    ]

    def state(self, baseline="2026-11-04T00:00:00Z", ids=()):
        return {"baseline": baseline, "ids": list(ids)}

    def test_counts_and_badge(self):
        tab = seen.counts(self.events, self.state(), NOW)
        self.assertEqual(tab, {"comment": 2, "vote": 1, "workitem": 0})  # d is 7d+ old, e is older than the window
        self.assertEqual(seen.badge_body(tab), "✎ 2 ✓ 1")

    def test_baseline_excludes_older_events(self):
        tab = seen.counts(self.events, self.state(baseline="2026-11-12T08:30:00Z"), NOW)
        self.assertEqual(tab, {"comment": 1, "vote": 1, "workitem": 0})

    def test_empty_badge_when_nothing_unseen(self):
        self.assertEqual(seen.badge_body(seen.counts(self.events, self.state(ids="abc"), NOW)), "")

    def test_opening_a_row_marks_its_thread(self):
        state = seen.mark_group(self.state(), self.events, self.events[0])
        self.assertEqual(state["ids"], ["a", "b"])
        self.assertEqual(seen.counts(self.events, state, NOW)["comment"], 0)

    def test_prune_drops_ids_that_left_the_window(self):
        state = seen.prune(self.state(ids=["a", "gone"]), self.events)
        self.assertEqual(state["ids"], ["a"])

    def test_first_load_sets_baseline_now(self):
        with tempfile.TemporaryDirectory() as directory:
            state = seen.load_seen(directory, NOW)
            self.assertEqual(state, {"baseline": "2026-11-12T12:00:00Z", "ids": []})
            self.assertEqual(seen.counts(self.events, state, NOW), {"comment": 0, "vote": 0, "workitem": 0})


class View(unittest.TestCase):
    events = Seen.events

    def test_kind_tabs_unseen_only_all_keeps_seen(self):
        state = {"baseline": "2026-11-04T00:00:00Z", "ids": ["b"]}
        self.assertEqual([e["id"] for e in seen.tab_events("comment", self.events, state, NOW)], ["a"])
        self.assertEqual([e["id"] for e in seen.tab_events("all", self.events, state, NOW)], ["c", "b", "a"])

    def test_first_tab_order_then_all(self):
        state = {"baseline": "2026-11-04T00:00:00Z", "ids": []}
        self.assertEqual(seen.first_tab(self.events, state, NOW), "comment")
        state["ids"] = ["a", "b"]
        self.assertEqual(seen.first_tab(self.events, state, NOW), "vote")
        state["ids"] = ["a", "b", "c"]
        self.assertEqual(seen.first_tab(self.events, state, NOW), "all")

    def test_age_text(self):
        self.assertEqual(seen.age_text("2026-11-12T11:58:00Z", NOW), "2m")
        self.assertEqual(seen.age_text("2026-11-12T10:00:00Z", NOW), "2h")
        self.assertEqual(seen.age_text("2026-11-10T12:00:00Z", NOW), "2d")

    def test_row_left_cuts_and_drops_vote_name(self):
        comment = {"kind": "comment", "ref": "!1", "author": "Ada", "text": "one\n two  three"}
        self.assertEqual(seen.row_left(comment, 40), "!1 Ada “one two three”")
        self.assertEqual(seen.row_left(comment, 10), "!1 Ada “o…")
        vote = {"kind": "vote", "ref": "!1", "author": "Grace", "text": "Grace voted 10"}
        self.assertEqual(seen.row_left(vote, 40), "!1 Grace voted 10")


class RunFetch(TempCache):
    def run_ok(self):
        return fetch.run_fetch(self.dir, run=fake_az, now=NOW, me="me@example.com", have_az=True)

    def test_first_run_has_empty_badge_then_new_events_count(self):
        self.assertEqual(self.run_ok(), "ok")
        self.assertEqual(read(self.dir, "badge"), "")
        state = fetch.read_state(self.dir)
        self.assertEqual((state["status"], state["ok"]), ("ok", str(int(NOW.timestamp()))))
        with open(os.path.join(self.dir, "seen.json"), "w") as handle:
            json.dump({"baseline": "2026-11-12T00:00:00Z", "ids": []}, handle)
        self.run_ok()
        self.assertEqual(read(self.dir, "badge"), "✎ 1 ✓ 1 # 1")

    def test_az_missing_disables_and_logs_once(self):
        for _ in range(2):
            self.assertEqual(fetch.run_fetch(self.dir, run=fake_az, now=NOW, me="me@example.com", have_az=False), "disabled")
        self.assertEqual(fetch.read_state(self.dir)["status"], "disabled")
        self.assertEqual(read(self.dir, "fetch.log").count("disabled"), 1)

    def test_not_signed_in_disables(self):
        self.assertEqual(fetch.run_fetch(self.dir, run=fake_az, now=NOW, me="", have_az=True), "disabled")

    def test_expired_auth_sets_auth_and_keeps_last_ok(self):
        self.run_ok()

        def expired(args):
            raise fetch.AzError("Please run 'az login' to setup account.")

        self.assertEqual(fetch.run_fetch(self.dir, run=expired, now=NOW, me="me@example.com", have_az=True), "auth")
        state = fetch.read_state(self.dir)
        self.assertEqual((state["status"], state["ok"]), ("auth", str(int(NOW.timestamp()))))

    def test_other_failure_is_error_and_counts_stay(self):
        self.run_ok()
        before = read(self.dir, "badge")

        def broken(args):
            raise fetch.AzError("connection reset")

        self.assertEqual(fetch.run_fetch(self.dir, run=broken, now=NOW, me="me@example.com", have_az=True), "error")
        self.assertEqual(read(self.dir, "badge"), before)

    def test_lock_prevents_second_fetch(self):
        first = fetch.take_lock(self.dir)
        self.assertIsNotNone(first)
        self.assertIsNone(fetch.take_lock(self.dir))
        shutil.rmtree(first)
        self.assertIsNotNone(fetch.take_lock(self.dir))


if __name__ == "__main__":
    unittest.main()
