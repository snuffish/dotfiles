#!/usr/bin/env python3
"""Lint the skills registry and reconcile the skill loaders with it.

    python3 -I sync_skills.py            # check: lint and report drift across loaders, change nothing
    python3 -I sync_skills.py --apply    # also fix links in ~/.claude/skills, ~/.gemini/config/skills, ~/.gemini/skills and the config links

The registry is the folder above this script's real location, so the script
works before any skill is linked. --registry points it at another clone.

Rules: SKILL.md › Rules.
Output is coloured on a terminal; piped or with NO_COLOR it is plain text.
Exit status: 1 when the lint finds errors or a link change fails; with
--exit-pending, 10 when check mode finds link changes to apply; else 0.
"""
import argparse, json, os, re, shutil, subprocess, sys, textwrap

MODULE_REF = re.compile(r'^- `([^`]*_modules/[^`]+\.md)`', re.M)
LINK_REF = re.compile(r'\]\(((?:\.\./)*[\w./-]*(?:SKILL\.md|_modules/[\w/-]+\.md|references/[\w./-]+))(?:#[^)]*)?\)')
MD_LINK_REF = re.compile(r'\]\(((?:\.\./)*[\w./-]+\.md)(?:#[^)]*)?\)')
GUARD = 'If any Module cannot be read, stop and report the path.'
RETIRED = re.compile(r'(?<![\w-])core/SKILL\.md|(?<![\w-])(?:core|git-worktrees|artifact-protocol|pr-counterpart|pr-host|project-profile|fan-out|outward-writes)`? §')

KNOWN_FM_KEYS = {
    'name', 'description', 'when_to_use', 'argument-hint', 'arguments',
    'disable-model-invocation', 'user-invocable', 'allowed-tools',
    'disallowed-tools', 'model', 'effort', 'context', 'agent', 'background',
    'hooks', 'paths', 'shell', 'metadata', 'license', 'compatibility'
}
BOOLEAN_KEYS = {'user-invocable', 'disable-model-invocation', 'background'}
BOOLEAN_VALUES = {
    'true': True, 'yes': True, 'on': True, '1': True,
    'false': False, 'no': False, 'off': False, '0': False
}

LOADER_TARGETS = {
    'claude': os.path.expanduser(os.path.join('~', '.claude', 'skills')),
    'antigravity': os.path.expanduser(os.path.join('~', '.gemini', 'config', 'skills')),
    'gemini': os.path.expanduser(os.path.join('~', '.gemini', 'skills')),
}

WORKTREE_DIRS = (
    os.path.join('.claude', 'worktrees'),
    os.path.join('.agents', 'worktrees'),
    os.path.join('.gemini', 'worktrees'),
)


class Style:
    """ANSI styling on a terminal; plain text when piped or NO_COLOR is set."""
    def __init__(self, enabled):
        self.enabled = enabled

    def _wrap(self, code, text):
        return f'\033[{code}m{text}\033[0m' if self.enabled else str(text)

    def bold(self, t): return self._wrap('1', t)
    def dim(self, t): return self._wrap('2', t)
    def red(self, t): return self._wrap('31', t)
    def green(self, t): return self._wrap('32', t)
    def yellow(self, t): return self._wrap('33', t)
    def cyan(self, t): return self._wrap('36', t)


HOME = os.path.expanduser('~')


def tilde(text):
    return text.replace(HOME + os.sep, '~' + os.sep)


def is_worktree_path(path):
    p = os.sep + path.strip(os.sep) + os.sep
    return any(os.sep + wt + os.sep in p for wt in WORKTREE_DIRS)


def is_monolithic_symlink(target_path, root):
    if os.path.islink(target_path):
        resolved = os.path.realpath(target_path)
        if resolved == root or resolved.startswith(root + os.sep):
            return True
        terminal_skills = os.path.expanduser(os.path.join('~', '.terminal', 'skills'))
        if resolved == terminal_skills or resolved.startswith(terminal_skills + os.sep):
            return True
    return False


def sanitize_target_dir(target_path, root):
    if is_monolithic_symlink(target_path, root):
        os.unlink(target_path)
    os.makedirs(target_path, exist_ok=True)


def read_list(path):
    """Names or paths from a one-per-line file; blank lines and # comments skipped."""
    if not os.path.isfile(path):
        return []
    lines = (line.split('#', 1)[0].strip() for line in open(path, encoding='utf-8'))
    return [line for line in lines if line]


def _check_md_links(base_dir, label, text, errors, full_md=False):
    refs = set(LINK_REF.findall(text))
    if full_md:
        refs.update(MD_LINK_REF.findall(text))
    for link in sorted(refs):
        if '<' in link or '…' in link or os.path.basename(link).startswith(('claude-', 'antigravity-')):
            continue
        if not os.path.exists(os.path.realpath(os.path.join(base_dir, link))):
            errors.append(f'{label}: dead link {link}')


def lint(root):
    """Walk the registry; return (skills, errors, warnings)."""
    modules = os.path.join(root, '_modules')
    errors, warnings, skills = [], [], {}
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in ('.git', 'flat-links')]
        if d == modules or d.startswith(modules + os.sep):
            if 'SKILL.md' in files:
                errors.append(f'{d}: SKILL.md inside _modules/')
            for f in sorted(files):
                if not f.endswith('.md') or f == 'SKILL.md':
                    continue
                mp = os.path.join(d, f)
                mtext = open(mp, encoding='utf-8').read()
                if mtext.startswith('---\n'):
                    errors.append(f'{mp}: frontmatter inside _modules/')
                _check_md_links(d, mp, mtext, errors, full_md=True)
                if RETIRED.search(mtext):
                    errors.append(f'{mp}: retired core link or numbered Module section')
                if sum(1 for line in mtext.splitlines() if line.lstrip().startswith('`' * 3)) % 2:
                    errors.append(f'{mp}: odd number of code fences (unclosed block)')
            continue
        if os.path.basename(d) == 'references' and os.path.isfile(os.path.join(os.path.dirname(d), 'SKILL.md')):
            for f in sorted(files):
                if not f.endswith('.md'):
                    continue
                rp = os.path.join(d, f)
                rtext = open(rp, encoding='utf-8').read()
                _check_md_links(d, rp, rtext, errors, full_md=True)
                if RETIRED.search(rtext):
                    errors.append(f'{rp}: retired core link or numbered Module section')
                if sum(1 for line in rtext.splitlines() if line.lstrip().startswith('`' * 3)) % 2:
                    warnings.append(f'{rp}: odd number of code fences (unclosed block)')
            continue
        if 'SKILL.md' not in files:
            continue
        text = open(os.path.join(d, 'SKILL.md'), encoding='utf-8').read()
        m = re.match(r'---\n(.*?)\n---\n', text, re.S)
        if not m:
            errors.append(f'{d}: no frontmatter')
            continue
        fm = m.group(1)
        fm_keys = {}
        for line in fm.splitlines():
            if not line or line.startswith('#'):
                continue
            if not line.startswith((' ', '\t')) and ':' in line:
                k, v = line.split(':', 1)
                fm_keys[k.strip()] = v.strip()
        for k in fm_keys:
            if k not in KNOWN_FM_KEYS:
                errors.append(f'{d}: unknown frontmatter field {k!r}')
        for bk in BOOLEAN_KEYS:
            if bk in fm_keys:
                raw_val = fm_keys[bk].lower().strip("\"'")
                if raw_val not in BOOLEAN_VALUES:
                    errors.append(f'{d}: {bk} must be boolean (true/false), got {fm_keys[bk]!r}')
        name = (re.search(r'^name:\s*(.+)$', fm, re.M) or [None, None])[1]
        raw = (re.search(r'^description:\s*(.+)$', fm, re.M) or [None, ''])[1].strip()
        desc = json.loads(raw) if raw.startswith('"') else raw.strip("'")
        folder = os.path.basename(d)
        rel = os.path.relpath(d, root).split(os.sep)
        project = rel[0] == 'Projects'
        if folder.endswith('-profile'):
            ui_val = fm_keys.get('user-invocable')
            if ui_val is None:
                errors.append(f"{d}: Profile skill missing required 'user-invocable: false'")
            elif BOOLEAN_VALUES.get(ui_val.lower().strip("\"'")) is not False:
                errors.append(f"{d}: Profile skill must have 'user-invocable: false'")
            if 'disable-model-invocation' in fm_keys:
                dmi_val = fm_keys['disable-model-invocation'].lower().strip("\"'")
                if BOOLEAN_VALUES.get(dmi_val) is True:
                    errors.append(f"{d}: Profile skill must not set 'disable-model-invocation: true'")
        if name != folder:
            errors.append(f'{d}: name {name!r} != folder {folder!r}')
        if not desc or desc in ('>', '>-', '|', '|-'):
            errors.append(f'{d}: description missing or multi-line')
        elif desc.startswith(('"', "'")):
            errors.append(f'{d}: description is quoted twice (starts with a literal quote)')
        elif len(desc) > 1024:
            errors.append(f'{d}: description {len(desc)} chars > 1024')
        elif len(desc) > 700:
            warnings.append(f'{d}: description {len(desc)} chars (listing budget)')
        if project and not (desc.startswith('[Project:') and 'Load ONLY when' in desc):
            errors.append(f'{d}: project skill not gated')
        mods = MODULE_REF.findall(text)
        for mod in mods:
            target = os.path.realpath(os.path.join(d, mod))
            if mod.startswith(('/', '~')) or not (os.path.isfile(target) and os.path.dirname(target) == modules):
                errors.append(f'{d}: Module path {mod!r} does not resolve into _modules/')
        if mods and GUARD not in text:
            errors.append(f'{d}: ## Modules has no stop sentence')
        _check_md_links(d, d, text, errors, full_md=False)
        if RETIRED.search(text):
            errors.append(f'{d}: retired core link or numbered Module section')
        if sum(1 for line in text.splitlines() if line.lstrip().startswith('`' * 3)) % 2:
            warnings.append(f'{d}: odd number of code fences (unclosed block)')
        if name == folder:
            if folder in skills:
                errors.append(f'{d}: duplicate skill name {folder!r} (already at {skills[folder]["path"]})')
            else:
                project_dir = os.path.dirname(d)
                link = (not project) or folder.endswith('-profile') or folder in read_list(os.path.join(project_dir, '.flat-links'))
                skills[folder] = {'path': d, 'project': rel[1] if project else None, 'link': link, 'compatibility': fm_keys.get('compatibility')}

    readme = os.path.join(root, 'README.md')
    if os.path.isfile(readme):
        rtext = open(readme, encoding='utf-8').read()
        actual_total = len(skills)
        actual_general = sum(m['project'] is None for m in skills.values())
        actual_proj = actual_total - actual_general
        actual_mods = sum(1 for f in os.listdir(modules) if f.endswith('.md') and os.path.isfile(os.path.join(modules, f))) if os.path.isdir(modules) else 0
        sm = re.search(r'(\d+)\s+skills total\s+—\s+(\d+)\s+general\s+\+\s+(\d+)\s+under\s+`Projects/[^`]+`\s+—\s+plus\s+(\d+)\s+Modules', rtext)
        if sm and (int(sm.group(1)), int(sm.group(2)), int(sm.group(3)), int(sm.group(4))) != (actual_total, actual_general, actual_proj, actual_mods):
            warnings.append(f'{readme}: inventory summary counts ({sm.group(1)} total, {sm.group(2)} general, {sm.group(3)} project, {sm.group(4)} modules) '
                            f'!= actual ({actual_total} total, {actual_general} general, {actual_proj} project, {actual_mods} modules)')
        row_skill_sum = 0
        for grp, kind, cnt_s, entries_col in re.findall(r'^\|\s*([^|]+?)\s*\|\s*(Command|Reference|Profile|Module)\s*\|\s*(\d+)\s*\|\s*([^|]+)\|', rtext, re.M):
            cnt = int(cnt_s)
            listed = len(re.findall(r'`[^`]+`', re.sub(r'\([^)]*\)', '', entries_col)))
            if cnt != listed:
                warnings.append(f'{readme}: inventory row {grp} ({kind}) says {cnt} but lists {listed}')
            if kind == 'Module':
                if cnt != actual_mods:
                    warnings.append(f'{readme}: inventory Module count {cnt} != actual {actual_mods}')
            else:
                row_skill_sum += cnt
        if row_skill_sum and row_skill_sum != actual_total:
            warnings.append(f'{readme}: inventory table skill rows sum to {row_skill_sum} != actual {actual_total}')
    drift_script = os.path.join(root, 'skill-drift', 'scripts', 'check_skill_drift.py')
    claims_file = os.path.join(root, 'skills-claims.json')
    if os.path.isfile(drift_script) and os.path.isfile(claims_file):
        proc = subprocess.run([sys.executable, '-I', drift_script, '--claims', claims_file, '--json'],
                              capture_output=True, text=True, encoding='utf-8')
        try:
            drift_data = json.loads(proc.stdout)
            for r in drift_data.get('results', []):
                if r.get('status') in ('fail', 'stale'):
                    errors.append(f"{r['file']}:{r['line']}: skill-drift {r['status'].upper()} ({r['kind']}) {r['value']}: {r['detail']}")
        except ValueError:
            errors.append(f'{drift_script}: failed to parse JSON output ({proc.stderr.strip() or proc.returncode})')
    return skills, errors, warnings


def discover_agents_skills(agents_dir, registry_skills):
    """Skills in ~/.agents/skills; registry skills take precedence on name clash."""
    found, shadowed = {}, []
    if not os.path.isdir(agents_dir):
        return found, shadowed
    for name in sorted(os.listdir(agents_dir)):
        d = os.path.join(agents_dir, name)
        if not os.path.isfile(os.path.join(d, 'SKILL.md')):
            continue
        if name in registry_skills:
            shadowed.append(name)
        else:
            found[name] = {'path': os.path.realpath(d), 'project': None, 'link': True}
    return found, shadowed


def discover_plugin_skills(plugins_file, settings_file, existing_skills):
    """Skills in Claude Code installed and enabled plugins; existing skills take precedence on name clash."""
    found, shadowed = {}, []
    if not os.path.isfile(plugins_file):
        return found, shadowed
    enabled = {}
    if os.path.isfile(settings_file):
        try:
            enabled = json.load(open(settings_file, encoding='utf-8')).get('enabledPlugins', {})
        except Exception:
            pass
    try:
        data = json.load(open(plugins_file, encoding='utf-8'))
    except Exception:
        return found, shadowed
    plugins = data.get('plugins', {})
    for plugin_id, entries in sorted(plugins.items(), key=lambda x: (x[0] != 'claude-mem@thedotmack', x[0])):
        if enabled.get(plugin_id) is False:
            continue
        if not isinstance(entries, list):
            continue
        for entry in entries:
            install_path = entry.get('installPath')
            if not install_path or not os.path.isdir(install_path):
                continue
            skills_dir = os.path.join(install_path, 'skills')
            if not os.path.isdir(skills_dir):
                continue
            for name in sorted(os.listdir(skills_dir)):
                d = os.path.join(skills_dir, name)
                if not os.path.isfile(os.path.join(d, 'SKILL.md')):
                    continue
                if name in existing_skills or name in found:
                    shadowed.append(name)
                else:
                    found[name] = {'path': os.path.realpath(d), 'project': None, 'link': True, 'plugin': plugin_id}
    return found, shadowed


def enabled_plugin_skill_names(plugins_file, settings_file):
    """Folder names of every SKILL.md in enabled plugins, at any depth (some plugins nest skills/<category>/<name>)."""
    try:
        enabled = json.load(open(settings_file, encoding='utf-8')).get('enabledPlugins', {})
        plugins = json.load(open(plugins_file, encoding='utf-8')).get('plugins', {})
    except Exception:
        return set()
    names = set()
    for plugin_id, entries in plugins.items():
        if enabled.get(plugin_id) is False or not isinstance(entries, list):
            continue
        for entry in entries:
            skills_dir = os.path.join(entry.get('installPath') or '', 'skills')
            for dirpath, _, files in os.walk(skills_dir):
                if 'SKILL.md' in files:
                    names.add(os.path.basename(dirpath))
    return names


def should_link(meta, is_claude):
    if not meta.get('link'):
        return False
    compat = meta.get('compatibility')
    if compat:
        compat_lower = compat.lower().strip("\"'")
        if is_claude and 'claude' not in compat_lower:
            return False
        if not is_claude and not any(k in compat_lower for k in ('antigravity', 'gemini', 'agy', 'all')):
            return False
    return True


def plan_links(root, flat, skills, agents_dir=None, agents_skills=None, plugin_skills=None, plugins_base=None, is_claude=False):
    """Return the link changes needed, as (action, name, target) tuples, plus untouched foreign dead links."""
    actions, foreign_dead = [], []
    combined = {}
    if not is_claude and plugin_skills:
        combined.update(plugin_skills)
    if agents_skills:
        combined.update(agents_skills)
    combined.update(skills)

    if is_monolithic_symlink(flat, root):
        for name, meta in sorted(combined.items()):
            if should_link(meta, is_claude):
                actions.append(('create', name, meta['path']))
        return actions, foreign_dead

    if os.path.isdir(flat):
        for item in sorted(os.listdir(flat)):
            p = os.path.join(flat, item)
            if not os.path.islink(p):
                continue
            target = os.path.normpath(os.path.join(flat, os.readlink(p)))
            if not os.path.exists(p):
                if target.startswith(root + os.sep) or (agents_dir and target.startswith(agents_dir + os.sep)) or (plugins_base and target.startswith(plugins_base + os.sep)):
                    actions.append(('prune', item, target))
                else:
                    foreign_dead.append(f'{item} -> {target}')
            elif target.startswith(root + os.sep) and item in combined and not should_link(combined[item], is_claude):
                actions.append(('unlink', item, target))
            elif target.startswith(os.path.join(root, 'Projects') + os.sep) and item in skills and not skills[item]['link']:
                actions.append(('unlink', item, target))
    for name, meta in sorted(combined.items()):
        if not should_link(meta, is_claude):
            continue
        p = os.path.join(flat, name)
        if not os.path.lexists(p):
            actions.append(('create', name, meta['path']))
        elif os.path.islink(p) and os.path.normpath(os.path.join(flat, os.readlink(p))) != meta['path']:
            actions.append(('repoint', name, meta['path']))
        elif not os.path.islink(p):
            foreign_dead.append(f'{name}: a real folder, not a link to {meta["path"]} (left alone)')
    return actions, foreign_dead


def apply_links(flat, actions):
    os.makedirs(flat, exist_ok=True)
    failed = []
    for action, name, target in actions:
        p = os.path.join(flat, name)
        try:
            if action in ('prune', 'unlink', 'repoint'):
                if os.path.lexists(p):
                    os.unlink(p)
            if action in ('create', 'repoint'):
                os.symlink(target, p, target_is_directory=True)
        except OSError as e:
            failed.append(f'{action} {name}: {e}')
    return failed


def shipped_skills(workspace):
    """Skill names a workspace's repos ship in host skill dirs (.claude/skills, .agents/skills, .gemini/skills)."""
    names = set()
    bases = [workspace]
    try:
        bases += [os.path.join(workspace, c) for c in sorted(os.listdir(workspace))]
    except OSError:
        pass
    for base in bases:
        for host in ('.claude', '.agents', '.gemini'):
            skills_dir = os.path.join(base, host, 'skills')
            if os.path.isdir(skills_dir):
                names.update(n for n in os.listdir(skills_dir) if os.path.isfile(os.path.join(skills_dir, n, 'SKILL.md')))
    return names


def check_workspaces(root, skills):
    """Read-only checks of each project's workspaces; returns (lines, warnings)."""
    lines, warnings = [], []
    projects_dir = os.path.join(root, 'Projects')
    projects = sorted(os.listdir(projects_dir)) if os.path.isdir(projects_dir) else []
    for project in projects:
        workspaces = read_list(os.path.join(projects_dir, project, '.workspaces'))
        if not workspaces:
            lines.append(f'{project}: no .workspaces file, workspace checks skipped')
            continue
        held = sorted(n for n, m in skills.items() if m['project'] == project and not m['link'])
        for ws in workspaces:
            path = os.path.realpath(os.path.expanduser(ws))
            if not os.path.isdir(path):
                lines.append(f'{project} @ {ws}: not on this machine, skipped')
                continue
            missing = [n for n in held if n not in shipped_skills(path)]
            if missing:
                warnings.append(f'{project} @ {ws}: {len(missing)} held-out skills neither linked nor shipped in a repo loader (.claude, .agents or .gemini skills/)\n'
                                f'{", ".join(missing)}\n→ add to Projects/{project}/.flat-links, or retire')
            cfg = os.path.join(path, '.agents', 'skills.json')
            if not os.path.isfile(cfg):
                lines.append(f'{project} @ {ws}: no .agents/skills.json (Antigravity not configured)')
                continue
            try:
                raw_entries = json.load(open(cfg, encoding='utf-8')).get('entries', [])
                entries = [os.path.realpath(os.path.expanduser(e['path'])) for e in raw_entries]
            except (ValueError, KeyError, TypeError, AttributeError) as e:
                warnings.append(f'{cfg}: unreadable ({e})')
                continue
            for e in entries:
                if not os.path.isdir(e):
                    warnings.append(f'{cfg}: entry {e} does not exist')
            default_root = os.path.realpath(os.path.expanduser(os.path.join('~', '.terminal', 'skills')))
            if root not in entries and not (is_worktree_path(root) and default_root in entries):
                warnings.append(f'{cfg}: general skills not listed\n→ add {{"path": "{root}"}}')
            proj_skills = sorted(n for n, m in skills.items() if m['project'] == project)
            shipped = shipped_skills(path)
            proj_dirs = {os.path.join(projects_dir, project), os.path.join(default_root, 'Projects', project)}
            covered = False
            for raw_e, epath in zip(raw_entries, entries):
                is_proj_dir = epath in proj_dirs or (os.path.basename(epath) == project and os.path.basename(os.path.dirname(epath)) == 'Projects')
                is_repo_skills = os.path.basename(epath) == 'skills' and os.path.basename(os.path.dirname(epath)) in ('.claude', '.agents', '.gemini')
                if is_proj_dir or is_repo_skills:
                    covered = True
                inc = raw_e.get('include_only')
                if is_proj_dir and isinstance(inc, list):
                    excluded = [n for n in proj_skills if not any(re.search(pat, n) for pat in inc) and n not in shipped]
                    if excluded:
                        warnings.append(f'{cfg}: include_only on {tilde(epath)} excludes {", ".join(excluded)}')
            if not covered:
                warnings.append(f'{cfg}: no entry loads the {project} skills (the registry folder or a repo skills dir)')
            lines.append(f'{project} @ {ws}: {len(held) - len(missing)}/{len(held)} held-out skills shipped by the repo · .agents/skills.json {len(entries)} entries')
    return lines, warnings


def check_global_antigravity(agents_dir, targets=None):
    """Check ~/.gemini/config/skills.json when present."""
    warnings = []
    cfg = os.path.expanduser(os.path.join('~', '.gemini', 'config', 'skills.json'))
    if not os.path.isfile(cfg):
        return warnings
    try:
        raw_entries = [e['path'] for e in json.load(open(cfg, encoding='utf-8')).get('entries', [])]
    except (ValueError, KeyError, TypeError, AttributeError) as e:
        return [f'{cfg}: unreadable ({e})']
    for p in raw_entries:
        if not os.path.isabs(p):
            warnings.append(f'{cfg}: entry {p!r} is not an absolute path (Antigravity rejects ~ in global skills.json)')
        elif not os.path.isdir(p):
            warnings.append(f'{cfg}: entry {p} does not exist')
    resolved = [os.path.realpath(os.path.expanduser(p)) for p in raw_entries]
    antigravity_managed = targets is None or 'antigravity' in targets
    if antigravity_managed:
        if os.path.isdir(agents_dir) and os.path.realpath(agents_dir) in resolved:
            warnings.append(f'{cfg}: entry {os.path.realpath(agents_dir)} is redundant (antigravity loader ~/.gemini/config/skills already links ~/.agents/skills)')
    else:
        if os.path.isdir(agents_dir) and os.path.realpath(agents_dir) not in resolved:
            warnings.append(f'{cfg}: ~/.agents/skills not listed\n→ add {{"path": "{os.path.realpath(agents_dir)}"}}')
    return warnings


# (label, source, link paths, legacy): paths are repo-relative or '~/…'.
# Repo links are written relative, home links absolute.
CONFIG_LINKS = (
    ('rules', '.claude/AGENTS.md', ('AGENTS.md', 'CLAUDE.md', '~/.claude/CLAUDE.md', '~/.gemini/GEMINI.md'), 'AGENTS.md'),
    ('settings', '.claude/settings.json', ('~/.claude/settings.json',), '~/.claude/settings.json'),
    ('statusline', 'claude/statusline.sh', ('~/.claude/statusline.sh',), None),
)


def config_path(repo, path):
    return os.path.expanduser(path) if path.startswith('~') else os.path.join(repo, path)


def read_bytes(path):
    with open(path, 'rb') as f:
        return f.read()


def plan_config_links(repo):
    """Return (actions, conflicts, errors); actions are (action, label, path, target)."""
    actions, conflicts, errors = [], [], []
    for label, source, links, legacy in CONFIG_LINKS:
        source = config_path(repo, source)
        legacy = legacy and config_path(repo, legacy)
        content = source
        if not os.path.isfile(source):
            if not (legacy and os.path.isfile(legacy) and not os.path.islink(legacy)):
                errors.append(f'config {label}: {tilde(source)} missing and nothing to adopt')
                continue
            actions.append(('adopt', label, legacy, source))
            content = legacy
        for link in links:
            in_repo = not link.startswith('~')
            link = config_path(repo, link)
            target = os.path.relpath(source, os.path.dirname(link)) if in_repo else source
            if not os.path.lexists(link):
                actions.append(('create', label, link, target))
            elif os.path.islink(link):
                if os.path.normpath(os.path.join(os.path.dirname(link), os.readlink(link))) != source:
                    actions.append(('repoint', label, link, target))
            elif os.path.isfile(link) and read_bytes(link) == read_bytes(content):
                actions.append(('same', label, link, target))
            else:
                conflicts.append(f'{link}: differs from {source}')
    return actions, conflicts, errors


PROJECT_CONFIG_SPECS = (
    ('CLAUDE.local.md', 'CLAUDE.local.md'),
    ('settings.local.json', os.path.join('.claude', 'settings.local.json')),
)


def plan_workspace_config_links(root):
    """Return (actions, conflicts, errors) for project configs linked into registered workspaces."""
    actions, conflicts, errors = [], [], []
    projects_dir = os.path.join(root, 'Projects')
    if not os.path.isdir(projects_dir):
        return actions, conflicts, errors

    for project in sorted(os.listdir(projects_dir)):
        project_path = os.path.join(projects_dir, project)
        if not os.path.isdir(project_path):
            continue
        workspaces = read_list(os.path.join(project_path, '.workspaces'))
        if not workspaces:
            continue

        for ws in workspaces:
            ws_path = os.path.realpath(os.path.expanduser(ws))
            if not os.path.isdir(ws_path):
                continue

            claude_linked = False
            for src_name, dest_rel in PROJECT_CONFIG_SPECS:
                source = os.path.join(project_path, src_name)
                if not os.path.isfile(source):
                    continue
                link = os.path.join(ws_path, dest_rel)
                target = source
                label = f'{project} {src_name}'
                if src_name == 'CLAUDE.local.md':
                    claude_linked = True

                if not os.path.lexists(link):
                    actions.append(('create', label, link, target))
                elif os.path.islink(link):
                    if os.path.realpath(link) != os.path.realpath(target):
                        actions.append(('repoint', label, link, target))
                elif os.path.isfile(link) and read_bytes(link) == read_bytes(source):
                    actions.append(('same', label, link, target))
                else:
                    conflicts.append(f'{link}: differs from {source}')

            if claude_linked:
                agents_link = os.path.join(ws_path, 'AGENTS.local.md')
                label = f'{project} AGENTS.local.md'
                target = 'CLAUDE.local.md'
                if not os.path.lexists(agents_link):
                    actions.append(('create', label, agents_link, target))
                elif os.path.islink(agents_link):
                    if os.readlink(agents_link) != target and os.path.realpath(agents_link) != os.path.realpath(os.path.join(ws_path, target)):
                        actions.append(('repoint', label, agents_link, target))
                elif os.path.isfile(agents_link) and read_bytes(agents_link) == read_bytes(os.path.join(project_path, 'CLAUDE.local.md')):
                    actions.append(('same', label, agents_link, target))
                else:
                    conflicts.append(f'{agents_link}: differs from {target}')

    return actions, conflicts, errors


def replace_with_link(target, link):
    """Swap the link into place in one rename, so readers never see the path missing."""
    tmp = f'{link}.tmp.{os.getpid()}'
    os.makedirs(os.path.dirname(link), exist_ok=True)
    try:
        os.symlink(target, tmp)
        os.replace(tmp, link)
    finally:
        if os.path.lexists(tmp):
            os.unlink(tmp)


def apply_config_links(actions):
    """Adopt legacy files into the repo first, then link; a legacy file is removed only once its links are in place."""
    failed, broken, adopted = [], set(), []
    for action, label, legacy, source in actions:
        if action != 'adopt':
            continue
        tmp = f'{source}.tmp.{os.getpid()}'
        try:
            os.makedirs(os.path.dirname(source), exist_ok=True)
            shutil.copy2(legacy, tmp)
            os.replace(tmp, source)
            adopted.append(legacy)
        except OSError as e:
            broken.add(label)
            failed.append(f'adopt {legacy}: {e}')
        finally:
            if os.path.lexists(tmp):
                os.unlink(tmp)
    for action, label, link, target in actions:
        if action == 'adopt' or label in broken:
            continue
        try:
            replace_with_link(target, link)
        except OSError as e:
            broken.add(label)
            failed.append(f'{action} {link}: {e}')
    for action, label, legacy, _ in actions:
        if action == 'adopt' and label not in broken and legacy in adopted and not os.path.islink(legacy):
            try:
                os.unlink(legacy)
            except OSError as e:
                failed.append(f'remove {legacy}: {e}')
    return failed



def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--apply', action='store_true', help='fix the loader links (default: report only)')
    parser.add_argument('--registry', help='registry root (default: the folder above this script)')
    parser.add_argument('--exit-pending', action='store_true', help='exit 10 when check mode finds link changes to apply (for the shell wrapper)')
    parser.add_argument('--targets', help='comma-separated loader targets to sync (default: claude,antigravity,gemini)')
    args = parser.parse_args()

    root = os.path.realpath(args.registry or os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
    agents_dir = os.path.expanduser(os.path.join('~', '.agents', 'skills'))
    plugins_file = os.path.expanduser(os.path.join('~', '.claude', 'plugins', 'installed_plugins.json'))
    plugins_settings = os.path.expanduser(os.path.join('~', '.claude', 'settings.json'))
    plugins_base = os.path.expanduser(os.path.join('~', '.claude', 'plugins'))

    if args.apply and not args.registry and is_worktree_path(root):
        sys.exit(f'refusing --apply from a worktree ({root}): it would point every link into it. Pass --registry <main checkout>/skills.')

    if args.targets:
        selected = [t.strip() for t in args.targets.split(',') if t.strip()]
        unknown = [t for t in selected if t not in LOADER_TARGETS]
        if unknown:
            sys.exit(f'unknown targets in --targets: {", ".join(unknown)}. Available: {", ".join(LOADER_TARGETS.keys())}')
        targets = {t: LOADER_TARGETS[t] for t in selected}
    else:
        targets = dict(LOADER_TARGETS)

    skills, errors, warnings = lint(root)
    agents_skills, agents_shadowed = discover_agents_skills(agents_dir, skills)
    existing_for_plugins = set(skills.keys()) | set(agents_skills.keys())
    plugin_skills, plugin_shadowed = discover_plugin_skills(plugins_file, plugins_settings, existing_for_plugins)
    claude_plugin_names = enabled_plugin_skill_names(plugins_file, plugins_settings)

    if args.apply:
        for target_name, target_path in targets.items():
            sanitize_target_dir(target_path, root)

    target_actions = {}
    target_foreign = {}
    target_failed = {}

    for target_name, target_path in targets.items():
        is_claude = (target_name == 'claude')
        # Claude Code already loads enabled plugins' skills; a ~/.agents copy (or alias of one) only bloats the skill listing.
        target_agents = {n: m for n, m in agents_skills.items() if os.path.basename(m['path']) not in claude_plugin_names} if is_claude else agents_skills
        actions, foreign_dead = plan_links(
            root, target_path, skills,
            agents_dir=agents_dir, agents_skills=target_agents,
            plugin_skills=plugin_skills, plugins_base=plugins_base,
            is_claude=is_claude
        )
        target_actions[target_name] = actions
        target_foreign[target_name] = foreign_dead
        if args.apply:
            target_failed[target_name] = apply_links(target_path, actions)
        else:
            target_failed[target_name] = []

    config_actions, config_conflicts, config_errors = plan_config_links(os.path.dirname(root))
    ws_cfg_actions, ws_cfg_conflicts, ws_cfg_errors = plan_workspace_config_links(root)
    all_config_actions = config_actions + ws_cfg_actions
    all_config_conflicts = config_conflicts + ws_cfg_conflicts
    errors += config_errors + ws_cfg_errors
    config_failed = apply_config_links(all_config_actions) if args.apply else []

    ws_lines, ws_warnings = check_workspaces(root, skills)
    warnings += ws_warnings + check_global_antigravity(agents_dir, targets)

    st = Style(sys.stdout.isatty() and not os.environ.get('NO_COLOR'))
    general = sum(m['project'] is None for m in skills.values())
    held = sorted(n for n, m in skills.items() if not m['link'])
    print(f"{st.bold('sync-skills')}  {st.dim(tilde(root))}")
    print(f'  {len(skills)} skills ({general} general, {len(skills) - general} project) · {len(held)} held out')
    for label, linked, shadowed in [('~/.agents/skills', agents_skills, agents_shadowed),
                                    ('plugins', plugin_skills, sorted(set(plugin_shadowed)))]:
        if linked or shadowed:
            names = f": {st.dim(', '.join(shadowed))}" if shadowed else ''
            print(f'  {label:<17} {len(linked)} linked · {len(shadowed)} shadowed{names}')

    mode = 'applied' if args.apply else 'check only (--apply to change)'
    print(f"\n{st.bold('Loaders')}  {st.dim(mode)}")
    rows = [('config', 'repo → ~/.claude, ~/.gemini, workspaces',
             [(a, [f'{label} ({tilde(p)})' for x, label, p, _ in all_config_actions if x == a]) for a in ('adopt', 'create', 'repoint', 'same')],
             all_config_conflicts, config_failed, False)]
    for target_name, target_path in targets.items():
        monolithic = not args.apply and is_monolithic_symlink(target_path, root)
        rows.append((target_name, tilde(target_path),
                     [(a, [n for x, n, _ in target_actions[target_name] if x == a]) for a in ('create', 'repoint', 'prune', 'unlink')],
                     target_foreign[target_name], target_failed[target_name], monolithic))
    width = max(len(r[0]) for r in rows)
    pwidth = max(len(r[1]) for r in rows)
    for name, path, actions, foreign, failed, monolithic in rows:
        changes = [(a, ns) for a, ns in actions if ns]
        if failed:
            glyph, colour = '✗', st.red
        elif changes or monolithic:
            glyph, colour = '●', st.yellow
        else:
            glyph, colour = '✓', st.green
        summary = ' · '.join(f'{a} {len(ns)}' for a, ns in changes)
        if monolithic:
            summary = ' · '.join(filter(None, ['monolithic symlink → registry root', summary]))
        if not summary:
            summary = 'applied' if args.apply and not failed else 'up to date'
        print(f'  {colour(glyph)} {name:<{width}}  {st.dim(f"{path:<{pwidth}}")}  {colour(summary)}')
        for a, ns in changes:
            for line in textwrap.wrap(', '.join(ns), shutil.get_terminal_size().columns - 8,
                                      initial_indent=f'{a}: ', subsequent_indent=' ' * (len(a) + 2), break_on_hyphens=False):
                print(f'      {st.dim(line)}')
        for label, items, paint in [('left alone', foreign, st.yellow), ('FAILED', failed, st.red)]:
            if items:
                print(f'      {paint(f"{label} {len(items)}")}')
                for i in items:
                    print(f'        {st.dim("-")} {tilde(i)}')

    if ws_lines:
        print(f"\n{st.bold('Workspaces')}")
        for line in ws_lines:
            print(f'  {tilde(line)}')

    err = st.red(f'✗ {len(errors)} errors') if errors else st.green('✓ 0 errors')
    warn = st.yellow(f'⚠ {len(warnings)} warnings') if warnings else st.green('✓ 0 warnings')
    print(f'\n{err}  {warn}')
    for glyph, paint, items in [('✗', st.red, errors), ('⚠', st.yellow, warnings)]:
        for i in items:
            head, *detail = i.replace(root + os.sep, '').split('\n')
            print(f'  {paint(glyph)} {tilde(head)}')
            for d in detail:
                print(f'      {st.dim(d)}')
    any_failed = any(target_failed.values()) or bool(config_failed)
    pending = not args.apply and (bool(all_config_actions) or any(target_actions.values())
                                  or any(is_monolithic_symlink(p, root) for p in targets.values()))
    sys.exit(1 if errors or any_failed else 10 if args.exit_pending and pending else 0)


if __name__ == '__main__':
    main()
