import os
import shutil
import subprocess
import tempfile
import time
import unittest

STATUS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ado-status")
PILL = "#[fg=colour16,bg=colour179,bold] ADO {} #[default]"


class AdoStatus(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)

    def write(self, name, text):
        with open(os.path.join(self.dir, name), "w") as handle:
            handle.write(text)

    def state(self, status, ok_ago=None, reason=""):
        ok = "" if ok_ago is None else int(time.time()) - ok_ago
        self.write("state", f"status={status}\nok={ok}\nreason={reason}\n")

    def run_status(self, *args, stale="999999"):
        env = dict(os.environ, ADO_CACHE=self.dir, ADO_STALE=stale)
        return subprocess.run([STATUS, *args], env=env, capture_output=True, text=True, timeout=10).stdout

    def test_counts_pill(self):
        self.state("ok", 60)
        self.write("badge", "✎ 2 ✓ 1")
        self.assertEqual(self.run_status(), PILL.format("✎ 2 ✓ 1"))

    def test_empty_when_nothing_unseen(self):
        self.state("ok", 60)
        self.write("badge", "")
        self.assertEqual(self.run_status(), "")

    def test_age_marker_after_30_minutes(self):
        self.state("ok", 2 * 3600 + 5)
        self.write("badge", "# 3")
        self.assertEqual(self.run_status(), "#[fg=colour16,bg=colour179,bold] ADO # 3 #[nobold,fg=colour94]·2h #[default]")

    def test_minutes_marker_under_an_hour(self):
        self.state("error", 45 * 60 + 5, "connection reset")
        self.write("badge", "# 3")
        self.assertIn("·45m", self.run_status())

    def test_no_marker_under_30_minutes(self):
        self.state("ok", 29 * 60)
        self.write("badge", "# 3")
        self.assertNotIn("·", self.run_status())

    def test_disabled_prints_nothing(self):
        self.state("disabled", None, "az is not installed")
        self.write("badge", "✎ 2")
        self.assertEqual(self.run_status(), "")

    def test_auth_prints_grey_pill(self):
        self.state("auth", 60)
        self.assertEqual(self.run_status(), "#[fg=colour244] ADO ! #[default]")

    def test_why_reports_state_and_reason(self):
        self.state("auth", 60, "Please run 'az login'")
        out = self.run_status("--why")
        self.assertIn("status: auth", out)
        self.assertIn("reason: Please run 'az login'", out)

    def test_stale_cache_starts_fetch_once_unless_locked(self):
        marker = os.path.join(self.dir, "fetched")
        bin_dir = os.path.join(self.dir, "bin")
        os.mkdir(bin_dir)
        fake = os.path.join(bin_dir, "ado-fetch")
        shutil.copy(STATUS, os.path.join(bin_dir, "ado-status"))
        with open(fake, "w") as handle:
            handle.write(f"#!/bin/sh\necho x >> {marker}\n")
        os.chmod(fake, 0o755)
        env = dict(os.environ, ADO_CACHE=self.dir, ADO_STALE="0")
        os.mkdir(os.path.join(self.dir, "fetch.lock"))
        subprocess.run([os.path.join(bin_dir, "ado-status")], env=env, capture_output=True, timeout=10)
        time.sleep(0.3)
        self.assertFalse(os.path.exists(marker))
        os.rmdir(os.path.join(self.dir, "fetch.lock"))
        subprocess.run([os.path.join(bin_dir, "ado-status")], env=env, capture_output=True, timeout=10)
        time.sleep(0.5)
        self.assertTrue(os.path.exists(marker))


if __name__ == "__main__":
    unittest.main()
