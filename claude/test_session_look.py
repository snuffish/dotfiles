#!/usr/bin/env python3
"""Tests for session-look.py: rule matching, hash fallback, event to state, OSC allowlist, hook smoke run."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("session_look", HERE / "session-look.py")
look = importlib.util.module_from_spec(spec)
spec.loader.exec_module(look)

CONFIG = json.loads((HERE / "session-colors.json").read_text())


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        look.STATE = Path(self.tmp.name)
        self.calls = []

    def fire(self, event, pane="%1", config=CONFIG, **extra):
        data = {"session_id": "s1", "hook_event_name": event, "cwd": "/x/GR.PRIIS/backend"} | extra
        return look.handle(data, config, pane, run=self.calls.append)

    def state(self):
        return json.loads((look.STATE / "s1.json").read_text())["state"]


class PickColor(unittest.TestCase):
    def test_first_matching_rule_wins(self):
        config = CONFIG | {"rules": [{"cwd": "*/a*", "color": "red"}, {"cwd": "*/a*", "color": "blue"}]}
        self.assertEqual(look.pick_color(config, "/p/abc"), "red")

    def test_branch_regex_must_match_too(self):
        config = CONFIG | {"rules": [{"cwd": "*", "branch": "^hotfix/", "color": "red"}, {"cwd": "*", "color": "cyan"}]}
        original = look.git_branch
        self.addCleanup(setattr, look, "git_branch", original)
        look.git_branch = lambda path: "feature/x"
        self.assertEqual(look.pick_color(config, "/p/abc"), "cyan")
        look.git_branch = lambda path: "hotfix/y"
        self.assertEqual(look.pick_color(config, "/p/abc"), "red")

    def test_hash_fallback_is_stable_and_valid(self):
        config = CONFIG | {"rules": []}
        first = look.pick_color(config, "/p/unlisted-repo")
        self.assertEqual(first, look.pick_color(config, "/p/unlisted-repo"))
        self.assertIn(first, config["colors"])

    def test_worktree_counts_as_its_main_repo(self):
        self.assertEqual(look.repo_name("/p/repo/.claude/worktrees/slug/sub"), "repo")


class EventToState(Base):
    def test_events(self):
        cases = [
            ("SessionStart", {}, "done"),
            ("UserPromptSubmit", {}, "working"),
            ("PreToolUse", {}, "working"),
            ("PermissionRequest", {}, "waiting"),
            ("Notification", {"notification_type": "permission_prompt"}, "waiting"),
            ("Notification", {"notification_type": "agent_needs_input"}, "waiting"),
            ("Stop", {}, "done"),
        ]
        for event, extra, want in cases:
            with self.subTest(event=event, extra=extra):
                self.fire(event, **extra)
                self.assertEqual(self.state(), want)

    def test_idle_prompt_keeps_done(self):
        self.fire("Stop")
        self.fire("Notification", notification_type="idle_prompt")
        self.assertEqual(self.state(), "done")

    def test_plan_overrides_working_and_done_but_not_waiting(self):
        self.fire("UserPromptSubmit", permission_mode="plan")
        self.assertEqual(self.state(), "plan")
        self.fire("PermissionRequest", permission_mode="plan")
        self.assertEqual(self.state(), "waiting")
        self.fire("Stop", permission_mode="plan")
        self.assertEqual(self.state(), "plan")

    def test_leaving_plan_mode_clears_it(self):
        self.fire("UserPromptSubmit", permission_mode="plan")
        self.fire("UserPromptSubmit", permission_mode="default")
        self.assertEqual(self.state(), "working")


class Tmux(Base):
    def test_frame_is_the_identity_colour_in_every_state(self):
        for event in ("UserPromptSubmit", "PermissionRequest", "Stop"):
            self.fire(event)
            self.assertIn(CONFIG["colors"]["blue"]["frame"], self.calls[-1])

    def test_pane_background_is_never_set(self):
        for event in ("SessionStart", "UserPromptSubmit", "PermissionRequest", "Stop"):
            self.fire(event)
            self.assertNotIn("window-style", self.calls[-1])

    def test_waiting_pill_is_a_filled_wait_tag(self):
        self.fire("PermissionRequest")
        pill = CONFIG["states"]["waiting"]["pill"]
        self.assertIn(f"#[bg={pill},fg=#11111b] ◆ WAIT #[default]", self.calls[-1])

    def test_square_is_a_pane_option_in_the_state_colour(self):
        self.fire("UserPromptSubmit")
        args = self.calls[-1]
        i = args.index("@claude_square")
        square = f"#[fg={CONFIG['states']['working']['pill']}]■#[fg=default]"
        self.assertEqual(args[i - 3:i + 2], ["-p", "-t", "%1", "@claude_square", square])
        self.assertNotIn("-w", args)

    def test_pane_title_is_the_repo(self):
        self.fire("UserPromptSubmit")
        self.assertEqual(self.calls[-1][-1], look.repo_name("/x/GR.PRIIS/backend"))

    def test_unchanged_state_makes_no_tmux_call(self):
        self.fire("UserPromptSubmit")
        before = len(self.calls)
        self.fire("PreToolUse")
        self.fire("PreToolUse")
        self.assertEqual(len(self.calls), before)

    def test_one_tmux_invocation_per_change(self):
        self.fire("UserPromptSubmit")
        self.assertEqual(len(self.calls), 1)

    def test_session_end_resets_and_removes_state(self):
        self.fire("UserPromptSubmit")
        self.fire("SessionEnd")
        self.assertIn("-pu", self.calls[-1])
        self.assertIn("@claude_frame", self.calls[-1])
        self.assertIn("@claude_pill", self.calls[-1])
        self.assertIn("@claude_square", self.calls[-1])
        self.assertFalse((look.STATE / "s1.json").exists())

    def test_no_tmux_pane_means_no_call(self):
        self.fire("UserPromptSubmit", pane=None)
        self.assertEqual(self.calls, [])

    def test_session_start_ignores_leftover_state(self):
        self.fire("PermissionRequest")
        self.fire("SessionStart")
        self.assertEqual(self.state(), "done")
        self.assertIn(CONFIG["colors"]["blue"]["frame"], self.calls[-1])


class Output(Base):
    def test_title_uses_only_allowlisted_sequence(self):
        out = self.fire("UserPromptSubmit", pane=None)
        seq = out["terminalSequence"]
        self.assertTrue(seq.startswith("\x1b]2;") and seq.endswith("\x07"))
        self.assertNotIn("\x1b", seq[1:-1].replace("]2;", ""))

    def test_osc_title_strips_control_characters(self):
        self.assertEqual(look.osc_title("a\x1bb\x07c"), "\x1b]2;abc\x07")

    def test_color_command_only_when_enabled(self):
        self.assertNotIn("initialUserMessage", self.fire("SessionStart"))
        on = self.fire("SessionStart", config=CONFIG | {"color_command": True})
        self.assertEqual(on["initialUserMessage"], "/color blue")

    def test_state_file_is_valid_json_with_badge_fields(self):
        self.fire("UserPromptSubmit")
        record = json.loads((look.STATE / "s1.json").read_text())
        for key in ("color", "frame", "state", "glyph", "label", "sgr"):
            self.assertIn(key, record)


class Smoke(unittest.TestCase):
    def test_script_fails_open_on_bad_input(self):
        res = subprocess.run([sys.executable, "-I", str(HERE / "session-look.py")], input="not json",
                             capture_output=True, text=True)
        self.assertEqual((res.returncode, res.stdout), (0, ""))

    def test_script_prints_hook_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"PATH": os.environ["PATH"], "SESSION_LOOK_DIR": tmp, "HOME": tmp}
            event = {"session_id": "s9", "hook_event_name": "UserPromptSubmit", "cwd": "/x/GR.PRIIS"}
            res = subprocess.run([sys.executable, "-I", str(HERE / "session-look.py")], input=json.dumps(event),
                                 capture_output=True, text=True, env=env)
            self.assertEqual(res.returncode, 0)
            self.assertIn("terminalSequence", json.loads(res.stdout))


if __name__ == "__main__":
    unittest.main()
