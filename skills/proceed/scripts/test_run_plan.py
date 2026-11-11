#!/usr/bin/env python3
"""Simulation of run-plan.sh with a fake `claude` and a stub gate script in a scratch git repo.

Run: python3 -I test_run_plan.py
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_plan  # noqa: E402

PLAN = "# Plan\n\n## Phase 1: First\ndo a\n\n## Phase 2: Second\ndo b\n"
STUB_GATES = """#!/usr/bin/env bash
case "$1" in
  tests) if [ "${GATE_FAIL_LABEL:-}" = "$RUN_PLAN_PHASE" ] && [ ! -f "fixed-$RUN_PLAN_PHASE" ]; then echo "FAILED test X"; exit 1; fi ;;
  budget) echo "budget: not on this branch"; exit 3 ;;
esac
exit 0
"""


class Sim:
    def __init__(self, test):
        self.tmp = Path(tempfile.mkdtemp(prefix="run-plan-sim-"))
        self.repo, self.art, self.glob = self.tmp / "repo", self.tmp / "art", self.tmp / "global"
        for d in (self.repo, self.art, self.glob, self.tmp / "transcripts"):
            d.mkdir()
        (self.glob / "rules.md").write_text("rule\n")
        (self.glob / "sync").mkdir()
        (self.glob / "sync" / "manifest.json").write_text("{}\n")
        self.git("init", "-q", "-b", "main")
        (self.repo / "README").write_text("x\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "init")
        self.plan = self.art / "claude-implementation_plan-sim.md"
        self.plan.write_text(PLAN)
        self.gates = self.tmp / "gates.sh"
        self.gates.write_text(STUB_GATES)
        self.gates.chmod(0o755)
        self.env = {
            **os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
            "RUN_PLAN_CLAUDE": str(HERE / "fake_claude.py"), "RUN_PLAN_ARTIFACT_DIR": str(self.art),
            "RUN_PLAN_GLOBAL_PATHS": str(self.glob), "RUN_PLAN_TRANSCRIPTS": str(self.tmp / "transcripts"),
            "RUN_PLAN_PR_BASE_CMD": "false", "FAKE_LEAK_FILE": str(self.glob / "rules.md"),
            "RUN_PLAN_GLOBAL_SKIP": str(self.glob / "sync"),
        }

    def git(self, *a):
        subprocess.run(["git", *a], cwd=self.repo, check=True, capture_output=True, env=getattr(self, "env", None))

    def run(self, *extra, **env):
        cmd = [str(HERE / "run-plan.sh"), str(self.plan), "--base", "main", "--gates", str(self.gates), *extra]
        return subprocess.run(cmd, cwd=self.repo, capture_output=True, text=True, env={**self.env, **env})

    @property
    def handoff(self):
        return (self.art / "runner-handoff-sim.md").read_text()

    def events(self):
        return [json.loads(ln) for ln in (self.art / "run-plan-sim" / "log.jsonl").read_text().splitlines()]

    def commits(self):
        wt = next((self.repo / ".claude" / "worktrees").iterdir())
        return subprocess.run(["git", "log", "--format=%s"], cwd=wt, capture_output=True, text=True).stdout.splitlines()


class RunnerSim(unittest.TestCase):
    def setUp(self):
        self.sim = Sim(self)

    def test_all_phases_pass_then_done_with_retro(self):
        r = self.sim.run()
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        h = self.sim.handoff
        self.assertEqual(run_plan.get_field(h, "Run-Status"), "DONE")
        self.assertEqual(run_plan.get_field(h, "Next-Phase"), "none")
        self.assertEqual(self.sim.commits()[:2], ["feat(sim): phase 2", "feat(sim): phase 1"])
        caveats = run_plan.get_caveats(h)
        self.assertIn("caveat 1", caveats)
        self.assertTrue(any("gate budget skipped" in c for c in caveats), caveats)
        retro = (self.sim.art / "runner-retro-sim.md").read_text()
        self.assertIn("| 1 First |", retro)
        self.assertIn("| 2 Second |", retro)

    def test_failing_gate_gets_two_fixes_then_blocks_then_resumes(self):
        r = self.sim.run(GATE_FAIL_LABEL="2")
        self.assertEqual(r.returncode, 1, r.stderr + r.stdout)
        h = self.sim.handoff
        self.assertEqual(run_plan.get_field(h, "Run-Status"), "BLOCKED")
        self.assertIn("FAILED test X", h)
        fixes = [e for e in self.sim.events() if e["event"] == "invoke" and e.get("kind") == "fix"]
        self.assertEqual(len(fixes), 2)
        self.assertEqual(self.sim.commits()[0], "feat(sim): phase 1")  # phase 2 never committed
        again = self.sim.run("--resume", GATE_FAIL_LABEL="2", FAKE_FIX_WORKS="1")
        self.assertEqual(again.returncode, 0, again.stderr + again.stdout)
        self.assertEqual(run_plan.get_field(self.sim.handoff, "Run-Status"), "DONE")
        self.assertNotIn("## Blocked", self.sim.handoff)

    def test_blocked_without_resume_stops(self):
        self.sim.run(GATE_FAIL_LABEL="1")
        r = self.sim.run()
        self.assertEqual(r.returncode, 1)
        self.assertIn("--resume", r.stderr)

    def test_global_change_blocks_without_a_fix_run(self):
        r = self.sim.run(FAKE_LEAK="1")
        self.assertEqual(r.returncode, 1, r.stderr + r.stdout)
        self.assertIn("changed:", self.sim.handoff)
        self.assertFalse([e for e in self.sim.events() if e.get("kind") == "fix"])
        self.assertEqual(self.sim.commits(), ["init"])

    def test_background_sync_under_a_skipped_tree_is_no_leak(self):
        r = self.sim.run(FAKE_OTHER_FILE=str(self.sim.glob / "sync" / "manifest.json"))
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        self.assertEqual(run_plan.get_field(self.sim.handoff, "Run-Status"), "DONE")
        self.assertFalse([c for c in run_plan.get_caveats(self.sim.handoff) if "manifest.json" in c])

    def test_global_change_by_another_session_is_a_caveat(self):
        r = self.sim.run(FAKE_OTHER_FILE=str(self.sim.glob / "rules.md"))
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        self.assertTrue(any("changed outside the phase" in c for c in run_plan.get_caveats(self.sim.handoff)))

    def test_global_change_without_a_transcript_blocks(self):
        r = self.sim.run(FAKE_OTHER_FILE=str(self.sim.glob / "rules.md"), FAKE_NO_TRANSCRIPT="1")
        self.assertEqual(r.returncode, 1, r.stderr + r.stdout)
        self.assertIn("changed:", self.sim.handoff)

    def test_handoff_without_next_phase_is_a_setup_error(self):
        handoff = self.sim.art / "runner-handoff-sim.md"
        handoff.write_text("# Handoff\n\n**Status:** Phases 1-2 done\n**Base:** `main`\n\n---\n")
        r = self.sim.run()
        self.assertEqual(r.returncode, 2, r.stderr + r.stdout)
        self.assertIn("Next-Phase", r.stderr)
        self.assertFalse((self.sim.art / "run-plan-sim" / "log.jsonl").exists())  # nothing ran

    def test_uncommitted_work_from_before_the_run_is_a_setup_error(self):
        self.sim.run("--max-phases", "1")  # commits phase 1, creates the worktree
        wt = next((self.sim.repo / ".claude" / "worktrees").iterdir())
        (wt / "earlier-work.txt").write_text("not this run's\n")
        r = self.sim.run()
        self.assertEqual(r.returncode, 2, r.stderr + r.stdout)
        self.assertIn("uncommitted changes from before the run", r.stderr)
        self.assertEqual(self.sim.commits()[0], "feat(sim): phase 1")
        resumed = self.sim.run("--resume")
        self.assertEqual(resumed.returncode, 0, resumed.stderr + resumed.stdout)

    def test_verifier_scope_creep_uses_the_fix_budget(self):
        creep = json.dumps({"missed_files": [], "scope_creep": [{"file": "x", "why": "unrelated", "needed_for_phase": False}],
                            "global_leaks": [], "summary": "creep"})
        r = self.sim.run(FAKE_VERIFY=creep)
        self.assertEqual(r.returncode, 1, r.stderr + r.stdout)
        self.assertEqual(len([e for e in self.sim.events() if e.get("kind") == "fix"]), 2)
        self.assertIn("scope_creep", self.sim.handoff)

    def test_verifier_global_leak_blocks_at_once(self):
        leak = json.dumps({"missed_files": [], "scope_creep": [], "global_leaks": [{"path": "~/.claude/CLAUDE.md", "why": "rule"}], "summary": ""})
        r = self.sim.run(FAKE_VERIFY=leak)
        self.assertEqual(r.returncode, 1)
        self.assertFalse([e for e in self.sim.events() if e.get("kind") == "fix"])

    def test_missing_phase_json_is_fixed_through_the_retry_budget(self):
        r = self.sim.run(FAKE_MISSING_JSON="1")
        self.assertEqual(r.returncode, 1)
        self.assertIn("phase-1.json was not written", self.sim.handoff)

    def test_pr_target_beats_the_base_line(self):
        r = self.sim.run("--max-phases", "1", RUN_PLAN_PR_BASE_CMD="echo refs/heads/parent-branch")
        self.assertEqual(r.returncode, 3, r.stderr + r.stdout)
        base = next(e for e in self.sim.events() if e["event"] == "base")
        self.assertEqual((base["base"], base["source"]), ("parent-branch", "pr"))
        self.assertEqual(run_plan.get_field(self.sim.handoff, "Run-Status"), "CONTINUE")

    def test_no_pr_and_no_base_line_blocks(self):
        self.sim.run("--max-phases", "1")  # creates the worktree and the handoff
        text = self.sim.handoff
        self.sim.art.joinpath("runner-handoff-sim.md").write_text(text.replace(f"**Base:** `main`\n", ""))
        cmd = [str(HERE / "run-plan.sh"), str(self.sim.plan), "--gates", str(self.sim.gates)]
        r = subprocess.run(cmd, cwd=self.sim.repo, capture_output=True, text=True, env=self.sim.env)
        self.assertEqual(r.returncode, 1, r.stderr + r.stdout)
        self.assertIn("no diff base", self.sim.handoff)


class Helpers(unittest.TestCase):
    def test_parse_phases_nests_subheadings_and_keeps_lettered_labels(self):
        plan = "## Phase 1: A\nx\n### detail\ny\n## Phase 4b — Lock\nz\n## Notes\nn\n"
        phases = run_plan.parse_phases(plan)
        self.assertEqual([p["label"] for p in phases], ["1", "4b"])
        self.assertIn("### detail", phases[0]["body"])
        self.assertNotIn("Notes", phases[1]["body"])

    def test_set_field_inserts_after_the_header_fields(self):
        text = "# H\n\n**Status:** x\n**Branch:** `b`\n\n---\n\n## 1. Goal\n"
        out = run_plan.set_field(text, "Run-Status", "CONTINUE")
        self.assertIn("**Branch:** `b`\n**Run-Status:** CONTINUE\n", out)
        self.assertEqual(run_plan.get_field(run_plan.set_field(out, "Run-Status", "DONE"), "Run-Status"), "DONE")

    def test_caveats_round_trip_and_dedupe(self):
        text = run_plan.set_caveats("# H\n\n**Status:** x\n\n---\n\n> gate\n", ["a", "b", "a"])
        self.assertEqual(run_plan.get_caveats(text), ["a", "b"])

    def test_transcript_scan_finds_claude_mem_writes_only(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "p").mkdir()
            line = json.dumps({"message": {"content": [{"type": "tool_use", "name": "mcp__plugin_claude-mem_mcp-search__work_state_write"}]}})
            other = json.dumps({"message": {"content": [{"type": "tool_use", "name": "Read"}]}})
            (Path(d) / "p" / "sid.jsonl").write_text(line + "\n" + other + "\n")
            os.environ["RUN_PLAN_TRANSCRIPTS"] = d
            try:
                self.assertEqual(run_plan.transcript_memory_writes("sid"), ["work_state_write"])
                self.assertEqual(run_plan.transcript_memory_writes("none"), [])
            finally:
                del os.environ["RUN_PLAN_TRANSCRIPTS"]

    def test_conventional_subject_check(self):
        self.assertTrue(run_plan.CONVENTIONAL.match("feat(api): add x"))
        self.assertTrue(run_plan.CONVENTIONAL.match("Chore: Fix y"))
        self.assertFalse(run_plan.CONVENTIONAL.match("added stuff"))


if __name__ == "__main__":
    unittest.main()
