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


class TestPushArtifacts(Base):
    def setUp(self) -> None:
        super().setUp()
        self.art = self.root / "art"
        repo = self.art / "Repo"
        (repo / "sfx" / "sub").mkdir(parents=True)
        home = str(Path.home())
        (repo / "x-plan-sfx.md").write_text(f"see `{home}/.cache/a.md` and {home}.\n")
        (repo / "x-handoff-sfx.md").write_text(f"/proceed {home}/.cache/x-handoff-sfx.md\n")
        (repo / "x-handoff-sfx-2.md").write_text("copy\n")
        (repo / "x-plan-other-sfx-old.md").write_text("no\n")
        (repo / "x-plan-sfxy.md").write_text("no\n")
        (repo / "sfx" / "sub" / "cases.md").write_text("c\n")
        (repo / "sfx" / "blob.bin").write_bytes(b"\0" + home.encode())
        patcher = mock.patch.object(on_pc, "ARTIFACT_ROOT", self.art)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_family_matches_suffix_collisions_and_folder_only(self) -> None:
        names = [str(p.relative_to(self.art / "Repo")) for p in on_pc.artifact_family(self.art / "Repo", "sfx")]
        self.assertEqual(names, ["x-handoff-sfx-2.md", "x-handoff-sfx.md", "x-plan-sfx.md",
                                 "sfx/blob.bin", "sfx/sub/cases.md"])

    def test_family_rejects_missing_and_bad_suffix(self) -> None:
        for suffix in ("nope", "../x", ""):
            with self.assertRaises(on_pc.SetupError):
                on_pc.artifact_family(self.art / "Repo", suffix)

    def test_rewrite_home_text_only_and_not_prefix_of_longer_name(self) -> None:
        data, changed = on_pc.rewrite_home(b"/Users/me/a /Users/meX /Users/me.bak /Users/me.",
                                           "/Users/me", "/home/me")
        self.assertEqual(data, b"/home/me/a /Users/meX /Users/me.bak /home/me.")
        self.assertTrue(changed)
        self.assertEqual(on_pc.rewrite_home(b"\0/Users/me", "/Users/me", "/home/me"), (b"\0/Users/me", False))

    def fake_ssh(self, existing: str = ""):
        calls: list[str] = []

        def fake_run(argv, **kw):
            cmd = argv[-1]
            calls.append(cmd)
            if cmd.startswith("printf"):
                return done("/home/pc")
            if "for f in" in cmd:
                return done(existing)
            if "rev-parse --abbrev-ref" in cmd:
                return done("other-branch\n")
            if argv[:2] == ["git", "rev-parse"]:
                return done(f"{Path.home()}/Projects/Repo/.git\n")
            return done()
        return calls, fake_run

    def test_push_stages_rewritten_files_and_prints_proceed(self) -> None:
        calls, fake_run = self.fake_ssh()
        staged: dict[str, bytes] = {}

        def fake_tar(local, remote_cmd, stdin=None):
            stage = Path(local[2])
            staged.update({str(p.relative_to(stage)): p.read_bytes() for p in stage.rglob("*") if p.is_file()})
            self.assertEqual(remote_cmd, "mkdir -p .cache/agent-artifacts/Repo && tar -C .cache/agent-artifacts/Repo -xf -")

        with mock.patch.object(on_pc, "run", side_effect=fake_run), \
                mock.patch.object(on_pc, "pipe_tar", side_effect=fake_tar):
            rc, out, err = self.call("push-artifacts", "sfx")
        self.assertEqual(rc, 0, err)
        self.assertEqual(staged["x-plan-sfx.md"], b"see `/home/pc/.cache/a.md` and /home/pc.\n")
        self.assertEqual(staged["sfx/blob.bin"], b"\0" + str(Path.home()).encode())
        self.assertIn("pushed 5 files to pc-test:/home/pc/.cache/agent-artifacts/Repo/", out)
        self.assertIn("in 2)", out)
        self.assertIn("pc checkout ~/Projects/Repo on other-branch", out)
        self.assertIn("continue on the PC: /proceed /home/pc/.cache/agent-artifacts/Repo/x-handoff-sfx.md", out)
        self.assertIn("continue on the PC: /proceed /home/pc/.cache/agent-artifacts/Repo/x-handoff-sfx-2.md", out)

    def test_existing_files_refused_without_force(self) -> None:
        _, fake_run = self.fake_ssh(existing="x-plan-sfx.md\n")
        with mock.patch.object(on_pc, "run", side_effect=fake_run), \
                mock.patch.object(on_pc, "pipe_tar") as tar:
            rc, _, err = self.call("push-artifacts", "sfx")
            self.assertEqual(rc, 2)
            self.assertIn("already on pc-test", err)
            tar.assert_not_called()
            rc, out, _ = self.call("push-artifacts", "sfx", "--force")
        self.assertEqual(rc, 0)
        self.assertIn("x-plan-sfx.md  (overwritten)", out)

    def test_dry_run_copies_nothing(self) -> None:
        _, fake_run = self.fake_ssh()
        with mock.patch.object(on_pc, "run", side_effect=fake_run), \
                mock.patch.object(on_pc, "pipe_tar") as tar:
            rc, out, _ = self.call("push-artifacts", "sfx", "--dry-run")
        self.assertEqual(rc, 0)
        self.assertIn("would push 5 files", out)
        tar.assert_not_called()


if __name__ == "__main__":
    unittest.main()
