#!/usr/bin/env python3
"""Tests for plan-lint.py. Run: python3 -I claude/test_plan_lint.py"""
import importlib.util
import pathlib
import unittest

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


if __name__ == "__main__":
    unittest.main()
