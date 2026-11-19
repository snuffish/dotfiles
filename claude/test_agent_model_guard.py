#!/usr/bin/env python3
"""Tests for agent-model-guard.py. Run: python3 -I claude/test_agent_model_guard.py"""
import importlib.util
import io
import json
import os
import pathlib
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("agent_model_guard", pathlib.Path(__file__).with_name("agent-model-guard.py"))
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


def call(tool="Agent", **tool_input):
    return {"tool_name": tool, "tool_input": tool_input}


def run_main(stdin_text, env=None):
    out = io.StringIO()
    with mock.patch("sys.stdin", io.StringIO(stdin_text)), mock.patch("sys.stdout", out), mock.patch.dict(os.environ, env or {}):
        code = guard.main()
    return code, out.getvalue()


class Decide(unittest.TestCase):
    def test_denies_builtin_types_without_model(self):
        for kind in ("general-purpose", "Explore", "Plan", "claude"):
            self.assertIsNotNone(guard.decide(call(subagent_type=kind)), kind)

    def test_denies_missing_type_and_empty_model(self):
        self.assertIsNotNone(guard.decide(call(prompt="x")))
        self.assertIsNotNone(guard.decide(call(subagent_type="Explore", model="")))
        self.assertIsNotNone(guard.decide(call(subagent_type="Explore", model=None)))

    def test_allows_when_model_named(self):
        for kind in ("general-purpose", "Explore", "Plan", "claude"):
            self.assertIsNone(guard.decide(call(subagent_type=kind, model="sonnet")), kind)
        self.assertIsNone(guard.decide(call(subagent_type="general-purpose", model="opus")))

    def test_task_tool_name_is_covered(self):
        self.assertIsNotNone(guard.decide(call("Task", subagent_type="Explore")))

    def test_allows_other_tools_and_missing_input(self):
        self.assertIsNone(guard.decide(call("Bash", command="ls")))
        self.assertIsNone(guard.decide({"tool_name": "Agent"}))
        self.assertIsNone(guard.decide({"tool_name": "Agent", "tool_input": None}))

    def test_allows_fork_and_custom_types(self):
        self.assertIsNone(guard.decide(call(subagent_type="fork")))
        self.assertIsNone(guard.decide(call(subagent_type="priis-review-track")))


class Main(unittest.TestCase):
    def test_allow_is_empty_stdout_exit_0(self):
        code, out = run_main(json.dumps(call(subagent_type="Explore", model="sonnet")))
        self.assertEqual((code, out), (0, ""))

    def test_deny_json_shape(self):
        code, out = run_main(json.dumps(call(subagent_type="Explore")))
        self.assertEqual(code, 0)
        hook = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(set(hook), {"hookEventName", "permissionDecision", "permissionDecisionReason"})
        self.assertEqual(hook["hookEventName"], "PreToolUse")
        self.assertEqual(hook["permissionDecision"], "deny")

    def test_malformed_json_exits_0(self):
        self.assertEqual(run_main("{not json"), (0, ""))

    def test_kill_switch(self):
        code, out = run_main(json.dumps(call(subagent_type="Explore")), {"CLAUDE_AGENT_MODEL_GUARD": "0"})
        self.assertEqual((code, out), (0, ""))


if __name__ == "__main__":
    unittest.main()
