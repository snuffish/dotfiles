#!/usr/bin/env python3
"""Tests for safety-guard.py. Run: python3 -I claude/test_safety_guard.py"""
import importlib.util
import pathlib
import unittest

SPEC = importlib.util.spec_from_file_location("safety_guard", pathlib.Path(__file__).with_name("safety-guard.py"))
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


class AzFileFlag(unittest.TestCase):
    def test_denies_a_flag_the_command_lacks(self):
        self.assertEqual(guard.az_file_flag("az repos pr show --id 1 --query description -o tsv --output-file /tmp/p.md"), "--output-file")
        self.assertEqual(guard.az_file_flag("az devops invoke --area git --output-file /tmp/t.json"), "--output-file")
        self.assertEqual(guard.az_file_flag("az repos pr show --id 1 --out-file /tmp/p.md"), "--out-file")

    def test_allows_the_commands_that_have_the_flag_and_a_redirect(self):
        self.assertIsNone(guard.az_file_flag("az rest --method get --url https://example.test/x --output-file /tmp/t.json"))
        self.assertIsNone(guard.az_file_flag("az devops invoke --area git --out-file /tmp/t.json"))
        self.assertIsNone(guard.az_file_flag("az repos pr show --id 1 -o tsv > /tmp/p.md"))

    def test_allows_the_flag_on_other_tools_and_in_quotes(self):
        self.assertIsNone(guard.az_file_flag("eslint --output-file report.json src"))
        self.assertIsNone(guard.az_file_flag('az repos pr update --id 1 --draft true --description "no --output-file flag"'))


class GrepOptionAfterPattern(unittest.TestCase):
    def test_denies_an_option_after_the_pattern(self):
        self.assertEqual(guard.grep_option_after_pattern('git -C /repo grep -n "enum Status" -A12 -- backend/source'), "-A12")
        self.assertEqual(guard.grep_option_after_pattern("git grep -n 'When to use' -A8 -- skills/commit/SKILL.md"), "-A8")
        self.assertEqual(guard.grep_option_after_pattern("git grep -n foo HEAD -m1"), "-m1")
        self.assertEqual(guard.grep_option_after_pattern("git -P grep -n safety -A1"), "-A1")

    def test_allows_options_before_the_pattern(self):
        for command in (
            "git grep --after-context 2 -n safety -- claude/settings.json",
            "git grep --context 1 -n safety",
            "git grep -n -e safety --and '(' -e guard --or -e chain ')' -- claude",
            'git -C /repo grep -n -A 3 -e "a b" -e c -- "*.md"',
            "git grep -n -B2 -A2 'x\\|y' e98ba2a99 -- backend/source",
            "git grep -c foo | sort -n",
            "git grep -n foo -- -odd-path",
            "git grep -n foo > out.txt",
            "git -C /repo log --all --grep foo -n 5",
            "grep -rn foo -A3 src",
        ):
            self.assertIsNone(guard.grep_option_after_pattern(command), command)


class BacktickInDoubleQuotes(unittest.TestCase):
    def test_denies_a_live_backtick(self):
        self.assertTrue(guard.backtick_in_double_quotes('git log -S"No `az` command takes" -- pr-host.md'))
        self.assertTrue(guard.backtick_in_double_quotes("python3 -I -c \"print(1<<3, '`whoami`')\""))
        self.assertTrue(guard.backtick_in_double_quotes("python3 -I - <<< \"print('`whoami`')\""))

    def test_allows_literal_backticks(self):
        for command in (
            "git log -S'No `az` command takes' -- pr-host.md",
            'git commit -m "Fix \\`foo\\` handling"',
            "echo `date`",
            "python3 - <<'EOF'\nprint(\"`x`\")\nEOF",
            "echo 'it\"s `fine`'",
        ):
            self.assertFalse(guard.backtick_in_double_quotes(command), command)


if __name__ == "__main__":
    unittest.main()
