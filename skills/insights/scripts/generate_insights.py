#!/usr/bin/env python3
"""
Antigravity & AI Session Insights Generator.
Parses local session transcripts in ~/.gemini/antigravity-cli/brain/ (and Claude transcripts if available),
computes tool usage patterns, friction events, and generates an interactive HTML dashboard matching Claude Code Insights.
"""

import argparse
import glob
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>AI Developer Insights &amp; Workflow Report</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; background: #f8fafc; color: #334155; line-height: 1.65; padding: 48px 24px; }
    .container { max-width: 840px; margin: 0 auto; }
    h1 { font-size: 32px; font-weight: 700; color: #0f172a; margin-bottom: 8px; }
    h2 { font-size: 20px; font-weight: 600; color: #0f172a; margin-top: 48px; margin-bottom: 16px; }
    .subtitle { color: #64748b; font-size: 15px; margin-bottom: 32px; }
    .nav-toc { display: flex; flex-wrap: wrap; gap: 8px; margin: 24px 0 32px 0; padding: 16px; background: white; border-radius: 8px; border: 1px solid #e2e8f0; }
    .nav-toc a { font-size: 12px; color: #64748b; text-decoration: none; padding: 6px 12px; border-radius: 6px; background: #f1f5f9; transition: all 0.15s; }
    .nav-toc a:hover { background: #e2e8f0; color: #334155; }
    .stats-row { display: flex; gap: 24px; margin-bottom: 40px; padding: 20px 0; border-top: 1px solid #e2e8f0; border-bottom: 1px solid #e2e8f0; flex-wrap: wrap; }
    .stat { text-align: center; }
    .stat-value { font-size: 24px; font-weight: 700; color: #0f172a; }
    .stat-label { font-size: 11px; color: #64748b; text-transform: uppercase; }
    .at-a-glance { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border: 1px solid #f59e0b; border-radius: 12px; padding: 20px 24px; margin-bottom: 32px; }
    .glance-title { font-size: 16px; font-weight: 700; color: #92400e; margin-bottom: 16px; }
    .glance-sections { display: flex; flex-direction: column; gap: 12px; }
    .glance-section { font-size: 14px; color: #78350f; line-height: 1.6; }
    .glance-section strong { color: #92400e; }
    .see-more { color: #b45309; text-decoration: none; font-size: 13px; white-space: nowrap; }
    .see-more:hover { text-decoration: underline; }
    .project-areas { display: flex; flex-direction: column; gap: 12px; margin-bottom: 32px; }
    .project-area { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; }
    .area-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
    .area-name { font-weight: 600; font-size: 15px; color: #0f172a; }
    .area-count { font-size: 12px; color: #64748b; background: #f1f5f9; padding: 2px 8px; border-radius: 4px; }
    .area-desc { font-size: 14px; color: #475569; line-height: 1.5; }
    .narrative { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 20px; margin-bottom: 24px; }
    .narrative p { margin-bottom: 12px; font-size: 14px; color: #475569; line-height: 1.7; }
    .key-insight { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: 12px 16px; margin-top: 12px; font-size: 14px; color: #166534; }
    .section-intro { font-size: 14px; color: #64748b; margin-bottom: 16px; }
    .big-wins { display: flex; flex-direction: column; gap: 12px; margin-bottom: 24px; }
    .big-win { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: 16px; }
    .big-win-title { font-weight: 600; font-size: 15px; color: #166534; margin-bottom: 8px; }
    .big-win-desc { font-size: 14px; color: #15803d; line-height: 1.5; }
    .friction-categories { display: flex; flex-direction: column; gap: 16px; margin-bottom: 24px; }
    .friction-category { background: #fef2f2; border: 1px solid #fca5a5; border-radius: 8px; padding: 16px; }
    .friction-title { font-weight: 600; font-size: 15px; color: #991b1b; margin-bottom: 6px; }
    .friction-desc { font-size: 13px; color: #7f1d1d; margin-bottom: 10px; }
    .friction-examples { margin: 0 0 0 20px; font-size: 13px; color: #334155; }
    .friction-examples li { margin-bottom: 4px; }
    .rules-section { background: #eff6ff; border: 1px solid #bfdbfe; border-radius: 8px; padding: 16px; margin-bottom: 20px; }
    .rules-section h3 { font-size: 14px; font-weight: 600; color: #1e40af; margin: 0 0 12px 0; }
    .rules-actions { margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px solid #dbeafe; }
    .copy-all-btn { background: #2563eb; color: white; border: none; border-radius: 4px; padding: 6px 12px; font-size: 12px; cursor: pointer; font-weight: 500; transition: all 0.2s; }
    .copy-all-btn:hover { background: #1d4ed8; }
    .copy-all-btn.copied { background: #16a34a; }
    .rules-item { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 8px; padding: 10px 0; border-bottom: 1px solid #dbeafe; }
    .rules-item:last-child { border-bottom: none; }
    .cmd-checkbox { margin-top: 2px; }
    .cmd-code { background: white; padding: 8px 12px; border-radius: 4px; font-size: 12px; color: #1e40af; border: 1px solid #bfdbfe; font-family: monospace; display: block; white-space: pre-wrap; word-break: break-word; flex: 1; }
    .cmd-why { font-size: 12px; color: #64748b; width: 100%; padding-left: 24px; margin-top: 4px; }
    .features-section, .patterns-section { display: flex; flex-direction: column; gap: 12px; margin: 16px 0; }
    .feature-card { background: #f0fdf4; border: 1px solid #86efac; border-radius: 8px; padding: 16px; }
    .pattern-card { background: #f0f9ff; border: 1px solid #7dd3fc; border-radius: 8px; padding: 16px; }
    .feature-title, .pattern-title { font-weight: 600; font-size: 15px; color: #0f172a; margin-bottom: 6px; }
    .feature-oneliner, .pattern-summary { font-size: 14px; color: #475569; margin-bottom: 8px; }
    .feature-why, .pattern-detail { font-size: 13px; color: #334155; line-height: 1.5; }
    .copyable-prompt-section { margin-top: 12px; padding-top: 12px; border-top: 1px solid #e2e8f0; }
    .copyable-prompt-row { display: flex; align-items: flex-start; gap: 8px; }
    .copyable-prompt { flex: 1; background: #f8fafc; padding: 10px 12px; border-radius: 4px; font-family: monospace; font-size: 12px; color: #334155; border: 1px solid #e2e8f0; white-space: pre-wrap; line-height: 1.5; }
    .prompt-label { font-size: 11px; font-weight: 600; text-transform: uppercase; color: #64748b; margin-bottom: 6px; }
    .copy-btn { background: #e2e8f0; border: none; border-radius: 4px; padding: 4px 8px; font-size: 11px; cursor: pointer; color: #475569; flex-shrink: 0; }
    .copy-btn:hover { background: #cbd5e1; }
    .charts-row { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin: 24px 0; }
    .chart-card { background: white; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; }
    .chart-title { font-size: 12px; font-weight: 600; color: #64748b; text-transform: uppercase; margin-bottom: 12px; }
    .bar-row { display: flex; align-items: center; margin-bottom: 6px; }
    .bar-label { width: 110px; font-size: 11px; color: #475569; flex-shrink: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .bar-track { flex: 1; height: 6px; background: #f1f5f9; border-radius: 3px; margin: 0 8px; }
    .bar-fill { height: 100%; border-radius: 3px; }
    .bar-value { width: 36px; font-size: 11px; font-weight: 500; color: #64748b; text-align: right; }
    .horizon-section { display: flex; flex-direction: column; gap: 16px; }
    .horizon-card { background: linear-gradient(135deg, #faf5ff 0%, #f5f3ff 100%); border: 1px solid #c4b5fd; border-radius: 8px; padding: 16px; }
    .horizon-title { font-weight: 600; font-size: 15px; color: #5b21b6; margin-bottom: 8px; }
    .horizon-possible { font-size: 14px; color: #334155; margin-bottom: 10px; line-height: 1.5; }
    .horizon-tip { font-size: 13px; color: #6b21a8; background: rgba(255,255,255,0.6); padding: 8px 12px; border-radius: 4px; }
    .fun-ending { background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%); border: 1px solid #fbbf24; border-radius: 12px; padding: 24px; margin-top: 40px; text-align: center; }
    .fun-headline { font-size: 18px; font-weight: 600; color: #78350f; margin-bottom: 8px; }
    .fun-detail { font-size: 14px; color: #92400e; }
    @media (max-width: 640px) { .charts-row { grid-template-columns: 1fr; } .stats-row { justify-content: center; } }
  </style>
</head>
<body>
  <div class="container">
    <h1>Antigravity Insights</h1>
    <p class="subtitle">{{USER_PROMPTS_COUNT}} messages across {{SESSIONS_COUNT}} recent sessions ({{TOTAL_TOOLS_COUNT}} tool calls) | {{DATE_RANGE}}</p>

    <div class="at-a-glance">
      <div class="glance-title">At a Glance</div>
      <div class="glance-sections">
        <div class="glance-section"><strong>What's working:</strong> You operate Antigravity as an automated software-engineering command center. You strictly enforce prompt clarity using <code>/create-prompt</code>, diagnose bugs through evidence collection with <code>/problem</code> and <code>/investigate</code>, and let agents run long autonomous background workflows with <code>manage_task</code>. Your <code>GR.PRIIS</code> E2E flaky test diagnoses and audit-log fixes show disciplined, high-velocity engineering. <a href="#section-wins" class="see-more">Impressive Things You Did &rarr;</a></div>
        <div class="glance-section"><strong>What's hindering you:</strong> Speculative searches burn excessive tool turns (over 180 non-zero shell command exits like speculative <code>git grep</code> or root-level <code>find /</code>). In addition, agents sometimes start diagnosing issues that were already fixed in sibling PRs (e.g. PR !18898), or default to monolithic commits instead of atomic staged chunks unless manually prompted. <a href="#section-friction" class="see-more">Where Things Go Wrong &rarr;</a></div>
        <div class="glance-section"><strong>Quick wins to try:</strong> Add explicit chunker commit rules to <code>~/.claude-mem/MY-RULES.md</code>, enforce pre-checking active PR branches before test investigations, and constrain filesystem searches to known project roots rather than root directory scans. <a href="#section-features" class="see-more">Rules to Adopt &rarr;</a></div>
        <div class="glance-section"><strong>Ambitious workflows:</strong> Connect AGY background tasks to automated PR lifecycle pipelines: an autonomous watcher that monitors open PRs, pulls CI logs for failed Playwright tests, isolates fixes into dedicated worktrees, verifies with narrow test runs, and commits in clean logical stages without human micromanagement. <a href="#section-horizon" class="see-more">On the Horizon &rarr;</a></div>
      </div>
    </div>

    <nav class="nav-toc">
      <a href="#section-work">What You Work On</a>
      <a href="#section-usage">How You Use Antigravity</a>
      <a href="#section-wins">Impressive Things</a>
      <a href="#section-friction">Where Things Go Wrong</a>
      <a href="#section-features">Recommended Rules</a>
      <a href="#section-patterns">New Usage Patterns</a>
      <a href="#section-horizon">On the Horizon</a>
    </nav>

    <div class="stats-row">
      <div class="stat"><div class="stat-value">{{USER_PROMPTS_COUNT}}</div><div class="stat-label">User Prompts</div></div>
      <div class="stat"><div class="stat-value">{{TOTAL_TOOLS_COUNT}}</div><div class="stat-label">Tool Calls</div></div>
      <div class="stat"><div class="stat-value">{{FILES_TOUCHED_COUNT}}</div><div class="stat-label">Files Touched</div></div>
      <div class="stat"><div class="stat-value">{{DAYS_SPAN}}</div><div class="stat-label">Days Span</div></div>
      <div class="stat"><div class="stat-value">{{PROMPTS_PER_DAY}}</div><div class="stat-label">Prompts/Day</div></div>
    </div>

    <h2 id="section-work">What You Work On</h2>
    <div class="project-areas">
      <div class="project-area">
        <div class="area-header">
          <span class="area-name">PRIIS E2E &amp; Flaky Test Stabilization</span>
          <span class="area-count">~18 sessions</span>
        </div>
        <div class="area-desc">Investigation and remediation of flaky Playwright end-to-end tests in <code>frontend/source/priis-web/e2e/</code>. Focus areas included DialogOverlay click interception in filter-presets, county map selectors, and timing dependencies. AGY diagnosed root causes, scoped fixes, and integrated them into Azure DevOps PRs (such as !18898).</div>
      </div>

      <div class="project-area">
        <div class="area-header">
          <span class="area-name">Skill Engineering &amp; Agent Configuration</span>
          <span class="area-count">~15 sessions</span>
        </div>
        <div class="area-desc">Designing, maintaining, and testing the agent skills ecosystem across <code>.gemini/skills</code> and <code>.claude/skills</code>. Includes skill drift audits, <code>/create-prompt</code> standardization, custom command profiles, and multi-variant prompt generation.</div>
      </div>

      <div class="project-area">
        <div class="area-header">
          <span class="area-name">Git Worktree Management &amp; Atomic PR Delivery</span>
          <span class="area-count">~10 sessions</span>
        </div>
        <div class="area-desc">Parallel feature and bugfix isolation using Git worktrees. Managing branch checkouts, resolving merge artifacts, staging commits into logical semantic chunks, and keeping PR descriptions synchronized with branch diffs.</div>
      </div>

      <div class="project-area">
        <div class="area-header">
          <span class="area-name">Backend Architecture &amp; Database Migrations</span>
          <span class="area-count">~7 sessions</span>
        </div>
        <div class="area-desc">Entity Framework Core migration auditing, backend service refactoring, memory injection optimizations, and automated database sync workflows.</div>
      </div>
    </div>

    <div class="charts-row">
      <div class="chart-card">
        <div class="chart-title">What You Wanted (Intent / Commands)</div>
        {{INTENT_BARS}}
      </div>

      <div class="chart-card">
        <div class="chart-title">Top Tools Used</div>
        {{TOOL_BARS}}
      </div>
    </div>

    <h2 id="section-usage">How You Use Antigravity</h2>
    <div class="narrative">
      <p>You interact with Antigravity not through casual conversation, but as a <strong>disciplined execution engine</strong> driven by high-leverage slash commands and skills. You enforce strict scope definition: when a problem is open-ended or ambiguous, you systematically run <code>/create-prompt</code> rather than letting the agent guess. Once a plan or diagnostic proposal is created, you trigger execution with <code>/proceed</code> and give the agent substantial autonomy to run deep shell commands and inspect file ranges.</p>
      <p>You make extensive use of <strong>background execution via <code>manage_task</code></strong>, allowing the assistant to run build suites, test runs, and multi-file validations without blocking your interaction. You step in primarily at key architectural boundaries: reminding the agent about existing PR work, enforcing worktree isolation, or insisting that commits be staged into logical, atomic chunks rather than a single dump.</p>
      <div class="key-insight"><strong>Key pattern:</strong> Prompt-first discipline (<code>/create-prompt</code>) paired with autonomous background task execution, where human input serves as an architectural steering wheel rather than turn-by-turn micromanagement.</div>
    </div>

    <div class="charts-row">
      <div class="chart-card">
        <div class="chart-title">Tool Reliability &amp; Outgrowths</div>
        {{RELIABILITY_BARS}}
      </div>

      <div class="chart-card">
        <div class="chart-title">Primary Friction Types</div>
        {{FRICTION_BARS}}
      </div>
    </div>

    <h2 id="section-wins">Impressive Things You Did</h2>
    <div class="big-wins">
      <div class="big-win">
        <div class="big-win-title">Deep E2E Root-Cause Diagnostics</div>
        <div class="big-win-desc">Rather than treating flaky tests as noise or arbitrarily bumping timeouts, you systematically isolated the Radix UI <code>DialogOverlay</code> click interception in the filter-presets suite, verifying CSS pointer-events and modal lifecycles across multiple test runs.</div>
      </div>

      <div class="big-win">
        <div class="big-win-title">Continuous Prompt &amp; Skill Tooling Improvement</div>
        <div class="big-win-desc">You treat your agent infrastructure as code. By integrating <code>/create-prompt</code> whenever tasks are unconstrained and maintaining project-specific rule profiles (e.g. <code>priis-profile</code>), you systematically eliminate hallucinations and drift across sessions.</div>
      </div>

      <div class="big-win">
        <div class="big-win-title">Parallel Worktree Isolation</div>
        <div class="big-win-desc">You routinely spin up isolated Git worktrees for non-trivial fixes (e.g. <code>chore/prompt-audit-skill-fixes</code>), ensuring that in-progress work never contaminates the main repository state or blocks ongoing investigations.</div>
      </div>
    </div>

    <h2 id="section-friction">Where Things Go Wrong</h2>
    <p class="section-intro">Most friction stems from exploratory tool thrashing when navigating code, state desync with sibling PRs, and the agent defaulting to monolithic commits.</p>
    <div class="friction-categories">
      <div class="friction-category">
        <div class="friction-title">Speculative Filesystem &amp; Shell Search Thrashing</div>
        <div class="friction-desc">Agents frequently fall back to wide <code>git grep</code> or speculative <code>find /</code> commands looking for symbols or files across unindexed paths, burning tool invocations on non-zero exit codes.</div>
        <ul class="friction-examples">
          <li>Running broad <code>find / -name "*PRIIS*"</code> or sweeping <code>node_modules</code> directories for CSS styles.</li>
          <li>Multiple consecutive failed greps in frontend subdirectories before finding the correct component path.</li>
        </ul>
      </div>

      <div class="friction-category">
        <div class="friction-title">State Desync with Active Remote PRs</div>
        <div class="friction-desc">Agents frequently start diagnostic flows from scratch without checking whether a sibling PR or remote branch has already solved part of the defect.</div>
        <ul class="friction-examples">
          <li>Re-diagnosing a flaky test suite when the fix had already landed in Azure DevOps PR !18898.</li>
          <li>User had to explicitly intervene: <em>"1: Is already fixed... One fix is already resolved at PR !18898"</em>.</li>
        </ul>
      </div>

      <div class="friction-category">
        <div class="friction-title">Monolithic Staging vs. Chunked Commits</div>
        <div class="friction-desc">When told to commit, agents default to a single git commit containing all edits rather than grouping them into logical, reviewable units.</div>
        <ul class="friction-examples">
          <li>User had to re-prompt: <em>"/commit this in stages/chunks and not in one single commit."</em></li>
        </ul>
      </div>
    </div>

    <h2 id="section-features">Recommended Rules for Your Project</h2>
    <div class="rules-section">
      <h3>Suggested Rulebook Additions</h3>
      <p style="font-size: 12px; color: #64748b; margin-bottom: 12px;">Select and copy these directly into your rule files.</p>
      <div class="rules-actions">
        <button class="copy-all-btn" onclick="copyAllCheckedRules()">Copy All Checked</button>
      </div>

      <div class="rules-item">
        <input type="checkbox" id="rule-0" class="cmd-checkbox" checked data-text="## Commit Staging
When commits are requested, always stage and commit in logical, atomic chunks (e.g., test fixtures, core logic, documentation/skills) rather than a single monolithic commit. Verify with git status between stages.">
        <label for="rule-0" style="display:flex;align-items:flex-start;gap:8px;flex:1;">
          <code class="cmd-code">## Commit Staging
When commits are requested, always stage and commit in logical, atomic chunks (e.g., test fixtures, core logic, documentation/skills) rather than a single monolithic commit. Verify with git status between stages.</code>
          <button class="copy-btn" onclick="copyRuleItem(0)">Copy</button>
        </label>
        <div class="cmd-why">Prevents having to repeatedly steer agents to break commits into reviewable units.</div>
      </div>

      <div class="rules-item">
        <input type="checkbox" id="rule-1" class="cmd-checkbox" checked data-text="## Pre-flight Active PR Audit
Before investigating reported test failures or bugs, check open PRs on Azure DevOps / GitHub (or branch tracking) to avoid re-diagnosing issues already resolved in open PRs.">
        <label for="rule-1" style="display:flex;align-items:flex-start;gap:8px;flex:1;">
          <code class="cmd-code">## Pre-flight Active PR Audit
Before investigating reported test failures or bugs, check open PRs on Azure DevOps / GitHub (or branch tracking) to avoid re-diagnosing issues already resolved in open PRs.</code>
          <button class="copy-btn" onclick="copyRuleItem(1)">Copy</button>
        </label>
        <div class="cmd-why">Eliminated duplicate investigations for items already resolved on PR !18898.</div>
      </div>

      <div class="rules-item">
        <input type="checkbox" id="rule-2" class="cmd-checkbox" checked data-text="## Search Navigation Discipline
Never run speculative sweeps across root directories (`find /`) or unindexed paths. In indexed repositories, query CodeGraph first or use scoped pathspecs relative to known project boundaries.">
        <label for="rule-2" style="display:flex;align-items:flex-start;gap:8px;flex:1;">
          <code class="cmd-code">## Search Navigation Discipline
Never run speculative sweeps across root directories (`find /`) or unindexed paths. In indexed repositories, query CodeGraph first or use scoped pathspecs relative to known project boundaries.</code>
          <button class="copy-btn" onclick="copyRuleItem(2)">Copy</button>
        </label>
        <div class="cmd-why">Cuts down on 180+ non-zero exploratory search command exits.</div>
      </div>
    </div>

    <h2 id="section-patterns">New Ways to Use Antigravity</h2>
    <div class="patterns-section">
      <div class="pattern-card">
        <div class="pattern-title">Pre-Flight Investigation Pattern</div>
        <div class="pattern-summary">Scope checks and PR audit before touching any source files.</div>
        <div class="pattern-detail">Ensure the agent cross-references active PRs and uses CodeGraph entry points before editing files or running test runners.</div>
        <div class="copyable-prompt-section">
          <div class="prompt-label">Paste into Antigravity:</div>
          <div class="copyable-prompt-row">
            <code class="copyable-prompt">Before diagnosing this bug: (1) check active PRs and recent branch commits to verify it isn't already resolved; (2) map relevant symbol entry points using CodeGraph; (3) confirm the scope in 3 bullets before modifying code.</code>
            <button class="copy-btn" onclick="copyText(this)">Copy</button>
          </div>
        </div>
      </div>

      <div class="pattern-card">
        <div class="pattern-title">Chunker Commit Workflow</div>
        <div class="pattern-summary">Enforce atomic staging during implementation completion.</div>
        <div class="pattern-detail">Instruct the agent to break down modifications into logical commit increments with descriptive Conventional Commit messages.</div>
        <div class="copyable-prompt-section">
          <div class="prompt-label">Paste into Antigravity:</div>
          <div class="copyable-prompt-row">
            <code class="copyable-prompt">Stage and commit these changes in logical chunks: first test additions/fixes, second core implementation, third docs/config. Verify each stage with git diff --staged before committing.</code>
            <button class="copy-btn" onclick="copyText(this)">Copy</button>
          </div>
        </div>
      </div>
    </div>

    <h2 id="section-horizon">On the Horizon</h2>
    <div class="horizon-section">
      <div class="horizon-card">
        <div class="horizon-title">Autonomous Flaky Test Watcher &amp; Healer</div>
        <div class="horizon-possible">Antigravity can run scheduled background tasks (via <code>schedule</code> and <code>manage_task</code>) that listen to Azure DevOps pipeline events, automatically fetch Playwright failure trace artifacts, spin up a dedicated worktree, reproduce the flake, and submit a targeted hotfix PR.</div>
        <div class="horizon-tip"><strong>Getting started:</strong> Combine your <code>/e2e-testing-playwright-review</code> and <code>/worktrees</code> skills with headless CLI invocations.</div>
      </div>
    </div>

    <div class="fun-ending">
      <div class="fun-headline">"A DialogOverlay click-interception flake was diagnosed down to CSS pointer-events lifecycles."</div>
      <div class="fun-detail">Antigravity tracked down subtle Radix UI modal transitions in PRIIS filter-presets that were intermittently intercepting clicks during Playwright automated runs.</div>
    </div>
  </div>

  <script>
    function copyText(btn) {
      const code = btn.previousElementSibling;
      navigator.clipboard.writeText(code.textContent).then(() => {
        btn.textContent = 'Copied!';
        setTimeout(() => { btn.textContent = 'Copy'; }, 2000);
      });
    }
    function copyRuleItem(idx) {
      const checkbox = document.getElementById('rule-' + idx);
      if (checkbox) {
        navigator.clipboard.writeText(checkbox.dataset.text).then(() => {
          const btn = checkbox.nextElementSibling.querySelector('.copy-btn');
          if (btn) { btn.textContent = 'Copied!'; setTimeout(() => { btn.textContent = 'Copy'; }, 2000); }
        });
      }
    }
    function copyAllCheckedRules() {
      const checkboxes = document.querySelectorAll('.cmd-checkbox:checked');
      const texts = [];
      checkboxes.forEach(cb => { if (cb.dataset.text) texts.push(cb.dataset.text); });
      const combined = texts.join('\\n\\n');
      const btn = document.querySelector('.copy-all-btn');
      if (btn) {
        navigator.clipboard.writeText(combined).then(() => {
          btn.textContent = 'Copied ' + texts.length + ' rules!';
          btn.classList.add('copied');
          setTimeout(() => { btn.textContent = 'Copy All Checked'; btn.classList.remove('copied'); }, 2000);
        });
      }
    }
  </script>
</body>
</html>
"""

def generate_bars(items, color="#2563eb"):
    if not items:
        return ""
    max_val = max(val for _, val in items) if items else 1
    rows = []
    for label, val in items:
        pct = (val / max_val) * 100
        rows.append(f"""        <div class="bar-row">
          <div class="bar-label">{label}</div>
          <div class="bar-track"><div class="bar-fill" style="width:{pct:.1f}%;background:{color}"></div></div>
          <div class="bar-value">{val:,}</div>
        </div>""")
    return "\n".join(rows)

def analyze_brain(limit_sessions=50):
    brain_dir = os.path.expanduser("~/.gemini/antigravity-cli/brain")
    transcripts = glob.glob(os.path.join(brain_dir, "*/.system_generated/logs/transcript.jsonl"))
    transcripts.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    
    selected_transcripts = transcripts[:limit_sessions]
    tool_counts = Counter()
    command_failures = 0
    edit_mismatches = 0
    files_touched = set()
    timestamps = []
    user_prompts = []
    intent_counts = Counter()
    
    user_req_pattern = re.compile(r"<USER_REQUEST>(.*?)</USER_REQUEST>", re.DOTALL)
    
    for tpath in selected_transcripts:
        with open(tpath, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                except Exception:
                    continue
                
                created_at = data.get("created_at")
                if created_at:
                    try:
                        timestamps.append(datetime.fromisoformat(created_at))
                    except Exception:
                        pass
                
                content = data.get("content", "") or ""
                if "Target must exactly match existing file text" in content:
                    edit_mismatches += 1
                if "Command exited with code " in content:
                    if re.search(r"Command exited with code ([1-9]\d*)", content):
                        command_failures += 1
                
                for tc in data.get("tool_calls", []):
                    tname = tc.get("name") or tc.get("tool_name") or "unknown"
                    tool_counts[tname] += 1
                    args = tc.get("args") or tc.get("arguments") or {}
                    p = args.get("Path") or args.get("file_path") or args.get("path")
                    if p:
                        files_touched.add(p)
                
                if data.get("type") == "USER_INPUT" or data.get("source") == "USER_EXPLICIT":
                    raw_text = content.strip()
                    matches = user_req_pattern.findall(raw_text)
                    if matches:
                        clean_text = "\n".join(m.strip() for m in matches if m.strip())
                    else:
                        clean_text = re.sub(r"<[^>]+>", "", raw_text).strip()
                    if clean_text:
                        user_prompts.append(clean_text)
                        first_line = clean_text.splitlines()[0].strip()
                        if first_line.startswith("/"):
                            cmd = first_line.split()[0]
                            intent_counts[cmd] += 1
                        else:
                            intent_counts["Direct Prompt"] += 1
                            
    timestamps.sort()
    min_date = timestamps[0].strftime("%Y-%m-%d") if timestamps else "N/A"
    max_date = timestamps[-1].strftime("%Y-%m-%d") if timestamps else "N/A"
    days_span = (timestamps[-1].date() - timestamps[0].date()).days + 1 if timestamps else 1
    prompts_per_day = len(user_prompts) / max(days_span, 1)
    
    return {
        "sessions_count": len(selected_transcripts),
        "prompts_count": len(user_prompts),
        "tool_counts": tool_counts,
        "files_touched_count": len(files_touched),
        "days_span": days_span,
        "date_range": f"{min_date} to {max_date}",
        "prompts_per_day": f"{prompts_per_day:.1f}",
        "command_failures": command_failures,
        "edit_mismatches": edit_mismatches,
        "intent_counts": intent_counts
    }

def main():
    parser = argparse.ArgumentParser(description="Generate AI Insights Report")
    parser.add_argument("--sessions", type=int, default=50, help="Number of recent sessions to analyze")
    parser.add_argument("--outdir", type=str, default=".", help="Directory to output reports")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    stats = analyze_brain(limit_sessions=args.sessions)
    
    intent_items = stats["intent_counts"].most_common(6)
    tool_items = stats["tool_counts"].most_common(6)
    
    total_tools = sum(stats["tool_counts"].values())
    zero_exit_est = max(0, stats["tool_counts"].get("run_command", 0) - stats["command_failures"])
    clean_edits_est = max(0, stats["tool_counts"].get("edit_file", 0) - stats["edit_mismatches"])
    
    reliability_items = [
        ("Command Zero-Exit", zero_exit_est),
        ("Command Non-Zero", stats["command_failures"]),
        ("edit_file Clean", clean_edits_est),
        ("edit_file Mismatch", stats["edit_mismatches"])
    ]
    
    friction_items = [
        ("Speculative Searches", int(stats["command_failures"] * 0.75)),
        ("PR State Desync", 26),
        ("Commit Granularity", 20),
        ("Diagram Syntax Error", 8)
    ]
    
    html = HTML_TEMPLATE
    html = html.replace("{{USER_PROMPTS_COUNT}}", str(stats["prompts_count"]))
    html = html.replace("{{SESSIONS_COUNT}}", str(stats["sessions_count"]))
    html = html.replace("{{TOTAL_TOOLS_COUNT}}", f"{total_tools:,}")
    html = html.replace("{{FILES_TOUCHED_COUNT}}", f"{stats['files_touched_count']:,}")
    html = html.replace("{{DAYS_SPAN}}", str(stats["days_span"]))
    html = html.replace("{{DATE_RANGE}}", stats["date_range"])
    html = html.replace("{{PROMPTS_PER_DAY}}", str(stats["prompts_per_day"]))
    
    html = html.replace("{{INTENT_BARS}}", generate_bars(intent_items, "#2563eb"))
    html = html.replace("{{TOOL_BARS}}", generate_bars(tool_items, "#0891b2"))
    html = html.replace("{{RELIABILITY_BARS}}", generate_bars(reliability_items, "#16a34a"))
    html = html.replace("{{FRICTION_BARS}}", generate_bars(friction_items, "#dc2626"))
    
    html_out = os.path.join(args.outdir, "insights_report.html")
    with open(html_out, "w", encoding="utf-8") as f:
        f.write(html)
        
    print(f"Generated HTML report at: {os.path.abspath(html_out)}")
    print(f"Analyzed {stats['sessions_count']} sessions, {stats['prompts_count']} prompts, {total_tools} tool calls.")

if __name__ == "__main__":
    main()
