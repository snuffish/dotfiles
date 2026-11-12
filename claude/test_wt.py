#!/usr/bin/env python3
"""Tests for wt.bash (wt-new, wt-status, wt-rm, wt-sweep) and the worktree hooks, against a throwaway repo + bare remote."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
WT = HERE.parent / "wt.bash"
GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}


def proc_start(pid):
    out = subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True, text=True,
                         env=os.environ | {"TZ": "UTC", "LC_ALL": "C"}).stdout
    return " ".join(out.split())


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name).resolve()
        self.remote, self.repo, self.reg = root / "remote.git", root / "repo", root / "sessions"
        self.reg.mkdir()
        self.env = os.environ | GIT_ENV | {"WT_SESSIONS_DIR": str(self.reg), "WT_SWEEP_LOG": str(root / "sweep.log")}
        self.git(root, "init", "-q", "--bare", str(self.remote))
        self.git(root, "init", "-q", "-b", "main", str(self.repo))
        self.git(self.repo, "remote", "add", "origin", str(self.remote))
        (self.repo / "a.txt").write_text("a\n")
        self.git(self.repo, "add", "a.txt")
        self.git(self.repo, "commit", "-q", "-m", "init")
        self.git(self.repo, "push", "-q", "-u", "origin", "main")
        self.git(self.repo, "remote", "set-head", "origin", "main")
        self.sleepers = []

    def tearDown(self):
        for p in self.sleepers:
            p.kill()
            p.wait()

    def git(self, cwd, *args):
        return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True,
                              env=getattr(self, "env", os.environ | GIT_ENV)).stdout.strip()

    def wt(self, *args, stdin=None):
        script = f'source "{WT}"; "$@"'
        return subprocess.run(["bash", "-c", script, "_", *args], capture_output=True, text=True, env=self.env,
                              input=stdin)

    def new(self, name, *args):
        r = self.wt("wt-new", str(self.repo), name, *args)
        self.assertEqual(r.returncode, 0, r.stderr)
        return Path(r.stdout.strip().splitlines()[-1])

    def rows(self):
        out = self.wt("wt-status", str(self.repo)).stdout
        return {Path(c[0]).name: c for c in (line.split("\t") for line in out.splitlines())}

    def cls(self, name):
        return self.rows()[name][5]

    def session(self, cwd, sid="s-live", pid=None, start=None):
        if pid is None:
            p = subprocess.Popen(["sleep", "60"])
            self.sleepers.append(p)
            pid = p.pid
        start = start or proc_start(pid)
        (self.reg / f"{pid}.json").write_text(json.dumps(
            {"pid": pid, "sessionId": sid, "cwd": str(cwd), "procStart": start}))
        return pid

    def commit(self, d, fname="b.txt"):
        (d / fname).write_text("x\n")
        self.git(d, "add", fname)
        self.git(d, "commit", "-q", "-m", fname)


class Status(Base):
    def test_clean_pushed_is_safe(self):
        d = self.new("t1")
        self.commit(d)
        self.git(d, "push", "-q", "origin", "HEAD")
        self.assertEqual(self.cls("t1"), "safe")

    def test_dirty_and_untracked_keep(self):
        d = self.new("t1")
        (d / "a.txt").write_text("changed\n")
        e = self.new("t2")
        (e / "new.txt").write_text("u\n")
        self.assertEqual(self.cls("t1"), "keep:dirty")
        self.assertEqual(self.cls("t2"), "keep:dirty")

    def test_committed_unpushed_keeps(self):
        self.commit(self.new("t1"))
        self.assertEqual(self.cls("t1"), "keep:unpushed")

    def test_no_upstream_zero_commits_is_safe(self):
        self.new("t1")
        self.assertEqual(self.cls("t1"), "safe")

    def test_detached_snapshot(self):
        snap = self.repo / ".claude/worktrees/review-x"
        self.git(self.repo, "worktree", "add", "-q", "--detach", str(snap), "main")
        self.assertEqual(self.cls("review-x"), "safe")
        self.session(snap / "sub")
        self.assertEqual(self.cls("review-x"), "keep:live")

    def test_live_dead_and_reused_pid(self):
        d = self.new("t1")
        pid = self.session(d)
        self.assertEqual(self.rows()["t1"][2], "alive")
        self.assertEqual(self.cls("t1"), "keep:live")
        self.session(d, pid=pid, start="Mon Jan  1 00:00:00 2001")
        self.assertEqual(self.cls("t1"), "safe")
        (self.reg / f"{pid}.json").unlink()
        self.session(d, pid=999999)
        self.assertEqual(self.cls("t1"), "safe")

    def test_lock_owner_alive_elsewhere_keeps(self):
        self.new("t1", "--session", "wt-run")
        self.session(self.repo, sid="wt-run")
        self.assertEqual(self.cls("t1"), "keep:live")

    def test_dead_owner_dirty_keeps(self):
        d = self.new("t1", "--session", "gone")
        (d / "a.txt").write_text("changed\n")
        self.session(d, pid=999999, sid="gone")
        self.assertEqual(self.cls("t1"), "keep:dirty")

    def test_unreadable_registry_is_unknown(self):
        self.new("t1")
        self.env["WT_SESSIONS_DIR"] = str(self.reg / "missing")
        self.assertEqual(self.cls("t1"), "keep:unknown")

    def test_include_copy_edited_keeps(self):
        (self.repo / ".gitignore").write_text(".env\n")
        (self.repo / ".env").write_text("A=1\n")
        (self.repo / ".worktreeinclude").write_text(".env\n")
        self.git(self.repo, "add", ".gitignore", ".worktreeinclude")
        self.git(self.repo, "commit", "-q", "-m", "ignore")
        self.git(self.repo, "push", "-q", "origin", "main")
        d = self.new("t1")
        self.assertEqual((d / ".env").read_text(), "A=1\n")
        self.assertEqual(self.cls("t1"), "safe")
        (d / ".env").write_text("A=2\n")
        self.assertEqual(self.cls("t1"), "keep:include")


class New(Base):
    def test_branch_lock_and_ticket(self):
        d = self.new("1-demo", "--branch", "feature/1_demo", "--session", "sid1")
        self.assertEqual(self.git(d, "branch", "--show-current"), "feature/1_demo")
        lock = self.rows()["1-demo"][6]
        for part in ("claude-skill:cw", "ticket:1", "branch:feature/1_demo", "session:sid1", "made:1"):
            self.assertIn(part, lock)

    def test_default_branch_and_no_upstream(self):
        d = self.new("x")
        self.assertEqual(self.git(d, "branch", "--show-current"), "chore/x")
        r = subprocess.run(["git", "-C", str(d), "rev-parse", "@{u}"], capture_output=True)
        self.assertNotEqual(r.returncode, 0)

    def test_bad_names_rejected(self):
        for name in ("../x", "a b", ".hidden", "a..b"):
            self.assertNotEqual(self.wt("wt-new", str(self.repo), name).returncode, 0, name)

    def test_no_origin_falls_back_to_head(self):
        self.git(self.repo, "remote", "remove", "origin")
        r = self.wt("wt-new", str(self.repo), "x")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("local HEAD", r.stderr)


class Remove(Base):
    def assert_kept(self, name):
        d = self.repo / ".claude/worktrees" / name
        r = self.wt("wt-rm", str(d))
        self.assertNotEqual(r.returncode, 0)
        self.assertTrue(d.exists())
        self.assertTrue(self.rows()[name][6])

    def test_refuses_each_keep_case(self):
        (self.new("dirty") / "a.txt").write_text("c\n")
        self.commit(self.new("unpushed"))
        self.session(self.new("live"))
        for name in ("dirty", "unpushed", "live"):
            self.assert_kept(name)

    def test_self_removes_own_tree(self):
        d = self.new("own", "--session", "me")
        self.session(d, sid="me")
        self.assertEqual(self.wt("wt-rm", str(d)).returncode, 1)
        r = self.wt("wt-rm", "--self", "me", str(d))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(d.exists())

    def test_branch_delete_rules(self):
        self.wt("wt-rm", str(self.new("zero")))
        self.assertEqual(self.git(self.repo, "branch", "--list", "chore/zero"), "")
        self.git(self.repo, "branch", "pre")
        self.wt("wt-rm", str(self.new("p", "--branch", "pre")))
        self.assertIn("pre", self.git(self.repo, "branch", "--list", "pre"))
        d = self.new("c")
        self.commit(d)
        self.git(d, "push", "-q", "origin", "HEAD")
        self.assertEqual(self.wt("wt-rm", str(d)).returncode, 0)
        self.assertIn("chore/c", self.git(self.repo, "branch", "--list", "chore/c"))

    def test_discard_removes_dirty_keeps_committed_branch(self):
        d = self.new("x")
        self.commit(d)
        (d / "a.txt").write_text("c\n")
        r = self.wt("wt-rm", "--discard", str(d))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(d.exists())
        self.assertIn("chore/x", self.git(self.repo, "branch", "--list", "chore/x"))

    def test_sweep_applies_only_safe(self):
        self.new("safe1")
        (self.new("dirty") / "a.txt").write_text("c\n")
        self.commit(self.new("unpushed"))
        self.session(self.new("live"))
        dry = self.wt("wt-sweep", str(self.repo))
        self.assertIn("would remove", dry.stdout)
        self.assertEqual(set(self.rows()), {"safe1", "dirty", "unpushed", "live"})
        r = self.wt("wt-sweep", str(self.repo), "--apply")
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        self.assertEqual(set(self.rows()), {"dirty", "unpushed", "live"})
        self.assertIn("removed", Path(self.env["WT_SWEEP_LOG"]).read_text())


class Hooks(Base):
    def hook(self, script, data):
        return subprocess.run(["bash", str(HERE / script)], input=json.dumps(data), capture_output=True, text=True,
                              env=self.env)

    def test_create_prints_path_last(self):
        r = self.hook("worktree-create.sh", {"session_id": "s1", "cwd": str(self.repo), "name": "h1"})
        self.assertEqual(r.returncode, 0, r.stderr)
        d = Path(r.stdout.strip().splitlines()[-1])
        self.assertEqual(d, self.repo / ".claude/worktrees/h1")
        self.assertIn("session:s1", self.rows()["h1"][6])

    def test_create_uses_cw_branch(self):
        self.env["CW_BRANCH"] = "feature/7_x"
        r = self.hook("worktree-create.sh", {"session_id": "s1", "cwd": str(self.repo), "name": "h1"})
        self.assertEqual(self.git(Path(r.stdout.strip().splitlines()[-1]), "branch", "--show-current"), "feature/7_x")

    def test_create_reuses_existing_tree(self):
        d = self.new("h1")
        self.commit(d)
        r = self.hook("worktree-create.sh", {"session_id": "s2", "cwd": str(self.repo), "name": "h1"})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(Path(r.stdout.strip()), d)
        self.assertEqual(self.git(d, "branch", "--show-current"), "chore/h1")

    def test_create_bad_name_fails(self):
        for name in ("../x", "a b"):
            r = self.hook("worktree-create.sh", {"session_id": "s1", "cwd": str(self.repo), "name": name})
            self.assertNotEqual(r.returncode, 0, name)

    def test_remove_hook_discards_dirty_keeps_branch(self):
        d = self.new("x", "--session", "s1")
        self.commit(d)
        (d / "a.txt").write_text("c\n")
        self.session(d, sid="s1")
        r = self.hook("worktree-remove.sh", {"session_id": "s1", "cwd": str(d), "worktree_path": str(d)})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(d.exists())
        self.assertIn("chore/x", self.git(self.repo, "branch", "--list", "chore/x"))


if __name__ == "__main__":
    unittest.main()
