#!/usr/bin/env python3
"""Unit tests for on_pc.py; ssh and tar are mocked, git runs for real in a temp repo."""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import on_pc  # noqa: E402


def done(stdout: str = "", rc: int = 0, stderr: str = "") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess([], rc, stdout, stderr)


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        patcher = mock.patch.object(on_pc, "LOCAL_ROOT", self.root / "runs")
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)
        env = mock.patch.dict(os.environ, {"ON_PC_HOST": "pc-test"})
        env.start()
        self.addCleanup(env.stop)

    def call(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = on_pc.main(list(argv))
        return rc, out.getvalue(), err.getvalue()


class TestArgv(Base):
    def test_ssh_argv_uses_host_and_batch_mode(self) -> None:
        argv = on_pc.ssh_argv("true")
        self.assertEqual(argv[0], "ssh")
        self.assertIn("BatchMode=yes", argv)
        self.assertIn("ConnectTimeout=5", argv)
        self.assertEqual(argv[-2:], ["pc-test", "true"])

    def test_local_tar_skips_appledouble_files(self) -> None:
        self.assertEqual(on_pc.tar_env()["COPYFILE_DISABLE"], "1")

    def test_default_dest_uses_main_checkout_name(self) -> None:
        with mock.patch.object(on_pc, "run", return_value=done("/x/.terminal/.git\n")):
            dest = on_pc.default_dest("r1")
        self.assertEqual(dest, on_pc.ARTIFACT_ROOT / ".terminal" / "on-snuffish-pc" / "r1")

    def test_default_host(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(on_pc.host(), "snuffish-pc")

    def test_task_after_double_dash_keeps_words(self) -> None:
        args = on_pc.parser().parse_args(["start", "--kind", "shell", "--", "echo", "a b"])
        self.assertEqual(args.task, ["--", "echo", "a b"])


class TestRunScript(Base):
    def test_shell_task_runs_task_file_not_inline(self) -> None:
        script = on_pc.run_script("shell", None)
        self.assertIn('zsh "$RUN/task.sh"', script)
        self.assertIn('mv "$RUN/exit.tmp" "$RUN/exit"', script)

    def test_claude_task_quotes_model(self) -> None:
        script = on_pc.run_script("claude", "sonnet; rm -rf x")
        self.assertIn("--dangerously-skip-permissions --model 'sonnet; rm -rf x'", script)
        self.assertIn('< "$RUN/prompt.txt"', script)

    def test_baseline_commit_has_fixed_identity(self) -> None:
        script = on_pc.run_script("shell", None)
        self.assertIn("-c user.name=on-pc -c user.email=on-pc@local commit", script)

    def test_script_runs_locally_and_writes_patch(self) -> None:
        """Run run.sh with zsh on this machine: exit file, log and a patch with a new file."""
        if not Path("/bin/zsh").exists():
            self.skipTest("zsh missing")
        rdir = self.root / "rd"
        (rdir / "work").mkdir(parents=True)
        (rdir / "work" / "a.txt").write_text("one\n")
        (rdir / "run.sh").write_text(on_pc.run_script("shell", None))
        (rdir / "task.sh").write_text("echo \"it's ok\"\necho two >> a.txt\necho new > b.txt\nexit 3\n")
        env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        env.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(["/bin/zsh", str(rdir / "run.sh")], check=True, env=env)
        self.assertEqual((rdir / "exit").read_text().strip(), "3")
        self.assertIn("it's ok", (rdir / "log.txt").read_text())
        patch = (rdir / "changes.patch").read_text()
        self.assertIn("+two", patch)
        self.assertIn("b/b.txt", patch)

    def test_prompt_has_rules_brief_and_task(self) -> None:
        prompt = on_pc.build_prompt('fix "it" now')
        self.assertIn("You run headless on Snuffish-PC", prompt)
        self.assertIn("You are a sub-agent.", prompt)
        self.assertTrue(prompt.rstrip().endswith('Task:\nfix "it" now'))
        self.assertNotIn("\n---\n", prompt)


class TestSyncFiles(Base):
    def test_untracked_in_ignored_out_deleted_dropped(self) -> None:
        repo = self.root / "repo"
        repo.mkdir()
        env = {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "PATH": os.environ["PATH"]}
        git = lambda *a: subprocess.run(["git", "-C", str(repo), *a], check=True, env=env, capture_output=True)  # noqa: E731
        git("init", "-q")
        (repo / ".gitignore").write_text("*.log\nbuild/\n")
        (repo / "kept.txt").write_text("x")
        (repo / "gone.txt").write_text("x")
        git("add", "-A")
        git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
        (repo / "gone.txt").unlink()
        (repo / "new.txt").write_text("x")
        (repo / "debug.log").write_text("x")
        (repo / "build").mkdir()
        (repo / "build" / "out.bin").write_text("x")
        with mock.patch.dict(os.environ, env):
            files = on_pc.sync_files(repo)
        self.assertEqual(files, [".gitignore", "kept.txt", "new.txt"])

    def test_not_a_repo_is_setup_error(self) -> None:
        with self.assertRaises(on_pc.SetupError):
            on_pc.sync_files(self.root)


class TestStart(Base):
    def test_unreachable_host_exits_2_without_retry(self) -> None:
        with mock.patch.object(on_pc, "run", return_value=done(rc=255, stderr="ssh: Could not resolve hostname")) as r:
            rc, out, err = self.call("start", "--kind", "shell", "--", "true")
        self.assertEqual(rc, 2)
        self.assertIn("pc-test unreachable", err)
        self.assertEqual(r.call_count, 1)

    def test_empty_task_exits_2(self) -> None:
        rc, _, err = self.call("start", "--kind", "shell", "--")
        self.assertEqual(rc, 2)
        self.assertIn("no task", err)

    def test_start_uploads_writes_meta_and_starts_tmux(self) -> None:
        calls: list[list[str]] = []

        def fake_run(argv, **kw):
            calls.append(argv)
            return done("abc1234\n" if "rev-parse" in argv[-1] else "")

        staged: dict[str, str] = {}

        def fake_upload(stage, run_id, repo, files):
            staged.update({p.name: p.read_text() for p in stage.iterdir()})
            self.assertIsNone(repo)

        with mock.patch.object(on_pc, "run", side_effect=fake_run), \
                mock.patch.object(on_pc, "upload", side_effect=fake_upload):
            rc, out, _ = self.call("start", "--kind", "shell", "--dest", str(self.root / "d"),
                                   "--", "echo", "it's \"quoted\" $HOME")
        self.assertEqual(rc, 0)
        self.assertEqual(staged["task.sh"], "echo it's \"quoted\" $HOME\n")
        tmux = calls[1][-1]
        self.assertTrue(tmux.startswith("tmux new-session -d -s onpc-"))
        self.assertIn("'zsh -l $HOME/.cache/on-snuffish-pc/", tmux)
        self.assertIn("pc_terminal_sha=abc1234", out)
        meta = json.loads(next((self.root / "runs").glob("*.json")).read_text())
        self.assertIsNone(meta["repo"])
        self.assertEqual(meta["dest"], str((self.root / "d").resolve()))


class TestStateAndSummary(Base):
    def meta(self, repo: str | None = None) -> dict:
        return {"id": "r1", "kind": "shell", "dest": str(self.root / "d"), "repo": repo}

    def test_state_parses_exit_code(self) -> None:
        with mock.patch.object(on_pc, "run", return_value=done("1\n")):
            self.assertEqual(on_pc.state("r1"), ("done", 1))
        with mock.patch.object(on_pc, "run", return_value=done("running\n")):
            self.assertEqual(on_pc.state("r1"), ("running", None))

    def test_failed_run_shows_tail(self) -> None:
        dest = self.root / "d"
        dest.mkdir()
        (dest / "log.txt").write_text("\n".join(f"line {i}" for i in range(50)) + "\n")
        text = on_pc.summary(self.meta(), "done", 1)
        self.assertIn("exit 1", text)
        self.assertIn("line 49", text)
        self.assertIn("line 20", text)
        self.assertNotIn("line 19\n", text)

    def test_success_shows_short_tail_and_out_names(self) -> None:
        dest = self.root / "d"
        (dest / "out" / "sub").mkdir(parents=True)
        (dest / "out" / "sub" / "r.csv").write_text("x")
        (dest / "log.txt").write_text("\n".join(f"line {i}" for i in range(50)) + "\n")
        text = on_pc.summary(self.meta(), "done", 0)
        self.assertIn("out/: sub/r.csv", text)
        self.assertIn("--- last 15 log lines ---", text)
        self.assertIn("line 35", text)
        self.assertNotIn("line 34\n", text)

    def test_patch_only_reported_with_sync(self) -> None:
        dest = self.root / "d"
        dest.mkdir()
        (dest / "changes.patch").write_text("diff --git a/x b/x\n")
        self.assertIn("apply --check", on_pc.summary(self.meta("/repo"), "done", 0))
        dest2 = self.root / "d"
        (dest2 / "changes.patch").write_text("")
        self.assertIn("patch: none", on_pc.summary(self.meta("/repo"), "done", 0))
        self.assertNotIn("patch", on_pc.summary(self.meta(None), "done", 0))

    def test_wait_polls_until_done_then_fetches(self) -> None:
        (self.root / "runs").mkdir()
        (self.root / "runs" / "r1.json").write_text(json.dumps(self.meta()))
        states = iter([("running", None), ("done", 0)])
        with mock.patch.object(on_pc, "state", side_effect=lambda _: next(states)), \
                mock.patch.object(on_pc, "fetch") as f, mock.patch.object(on_pc.time, "sleep"):
            rc, out, _ = self.call("wait", "r1", "--poll", "0")
        self.assertEqual(rc, 0)
        f.assert_called_once()
        self.assertIn("run r1 (shell): done, exit 0", out)

    def test_unknown_id_exits_2(self) -> None:
        rc, _, err = self.call("fetch", "nope")
        self.assertEqual(rc, 2)
        self.assertIn("unknown run id", err)


if __name__ == "__main__":
    unittest.main()
