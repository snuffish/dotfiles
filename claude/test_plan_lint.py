#!/usr/bin/env python3
"""Tests for plan-lint.py. Run: python3 -I claude/test_plan_lint.py"""
import importlib.util
import io
import json
import pathlib
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("plan_lint", pathlib.Path(__file__).with_name("plan-lint.py"))
lint = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lint)

TAIL = "\n## 7. Open Questions\n\nNone.\n"


def session_problems(body):
    return [p for p in lint.problems_in(body + TAIL) if "session-scoped path" in p]


class SessionPaths(unittest.TestCase):
    def test_flags_scratchpad_and_tmp_paths(self):
        for line in (
            "- [MODIFY] replace with `<scratchpad>/commit-proposal/SKILL.md`",
            "- Script: `/tmp/tally.py`",
            "- Script: `/private/tmp/claude-501/-Users-x/3d4f3146-e9cf-44e6-b4f6-f4a119b1acee/scratchpad/a.py`",
            "**Inputs:** proposal `<scratchpad>/proposal/`",
            "| Baseline | `/tmp/baseline.json` |",
        ):
            with self.subTest(line=line):
                self.assertEqual(len(session_problems(line)), 1)

    def test_flags_a_path_inside_a_code_block(self):
        self.assertEqual(len(session_problems("```bash\npython3 -I /tmp/x.py\n```")), 1)

    def test_allows_durable_paths(self):
        for line in (
            "- Script: `~/.cache/agent-artifacts/.terminal/usage-cost-fixes/tally.py`",
            "- Fixture under `<artifact-dir>/<suffix>/event.json`",
            "- Edit `skills/tmp/notes.md` and `~/tmp/x`",
            "- Use `mktemp` for the draft",
        ):
            with self.subTest(line=line):
                self.assertEqual(session_problems(line), [])

    def test_reports_the_line_number(self):
        problems = session_problems("# Plan\n\n- ok\n- see `/tmp/a`")
        self.assertTrue(problems[0].startswith("L4:"), problems)


class Handoffs(unittest.TestCase):
    def test_picks_up_plans_and_handoffs_only(self):
        for name, expected in (
            ("claude-opus-5.5-implementation_plan-x.md", True),
            ("claude-opus-5.5-handoff-auth-flow.md", True),
            ("handoffs.md", False),
            ("SKILL.md", False),
        ):
            with self.subTest(name=name):
                event = {"tool_name": "Write", "tool_input": {"file_path": f"/a/{name}"}}
                self.assertEqual(lint.candidate_paths(event) == [f"/a/{name}"], expected)

    def test_finds_a_handoff_published_through_bash(self):
        event = {"tool_name": "Bash", "tool_input": {"command": "bash publish_new_artifact.sh d.md /a/x-handoff-y"},
                 "tool_response": {"stdout": "/a/x-handoff-y.md"}}
        self.assertIn("/a/x-handoff-y.md", lint.candidate_paths(event))

    def test_handoff_gets_only_the_path_check(self):
        with tempfile.TemporaryDirectory() as folder:
            handoff = pathlib.Path(folder, "claude-opus-5.5-handoff-x.md")
            handoff.write_text("# Handoff\n\nA long prose line with far more than fifteen words in it, which a plan would "
                               "flag but a handoff must not.\n- proposal at `<scratchpad>/p.md`\n", encoding="utf-8")
            event = {"tool_name": "Write", "tool_input": {"file_path": str(handoff)}}
            with mock.patch("sys.stdin", io.StringIO(json.dumps(event))), \
                    mock.patch("sys.stdout", new_callable=io.StringIO) as out:
                lint.main()
            reminder = json.loads(out.getvalue())["hookSpecificOutput"]["additionalContext"]
        self.assertIn("L4: session-scoped path", reminder)
        self.assertNotIn("Open Questions", reminder)
        self.assertNotIn("words", reminder)

    def test_clean_handoff_prints_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            handoff = pathlib.Path(folder, "claude-opus-5.5-handoff-x.md")
            handoff.write_text("# Handoff\n\n- proposal at `~/.cache/agent-artifacts/r/x/p.md`\n", encoding="utf-8")
            event = {"tool_name": "Write", "tool_input": {"file_path": str(handoff)}}
            with mock.patch("sys.stdin", io.StringIO(json.dumps(event))), \
                    mock.patch("sys.stdout", new_callable=io.StringIO) as out:
                lint.main()
        self.assertEqual(out.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
