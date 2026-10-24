#!/usr/bin/env python3
"""Lint the skills registry and reconcile the skill loaders with it.

    python3 -I sync_skills.py            # check: lint and report drift across loaders, change nothing
    python3 -I sync_skills.py --apply    # also fix links in ~/.claude/skills, ~/.gemini/config/skills, ~/.gemini/skills

The registry is the folder above this script's real location, so the script
works before any skill is linked. --registry points it at another clone.

Loader targets (see SKILL.md › Rules):
- claude: ~/.claude/skills
- antigravity: ~/.gemini/config/skills
- gemini: ~/.gemini/skills

Loader rules:
- every general skill and every Profile (*-profile) gets one symlink
  in each target pointing at its registry folder;
- a project skill is linked only when Projects/<Project>/.flat-links lists it;
- every skill in ~/.agents/skills/<name> gets one symlink in each target
  unless the registry already defines <name> (registry wins on name clash);
- monolithic symlinks to registry root are converted to directories of leaf links on --apply;
- only dead links into the registry or ~/.agents/skills are pruned; other links are reported.

Workspace checks, read-only: Projects/<Project>/.workspaces lists the
workspaces that use the project (one path per line, ~ allowed). For each one
that exists on this machine, the script reports project skills that are
neither linked nor shipped in a repo's host skills/ folder, and problems in the
workspace's .agents/skills.json.

Exit status: 1 when the lint finds errors, else 0.
"""
import argparse, json, os, re, sys

MODULE_REF = re.compile(r'^- `([^`]*_modules/[^`]+\.md)`', re.M)
LINK_REF = re.compile(r'\]\(((?:\.\./)*[\w./-]*(?:SKILL\.md|_modules/[\w-]+\.md|references/[\w./-]+))(?:#[^)]*)?\)')
GUARD = 'If any Module cannot be read, stop and report the path.'
RETIRED = re.compile(r'(?<![\w-])core/SKILL\.md|(?<![\w-])(?:core|git-worktrees|artifact-protocol)`? §')

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


def lint(root):
    """Walk the registry; return (skills, errors, warnings)."""
    modules = os.path.join(root, '_modules')
    errors, warnings, skills = [], [], {}
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x != '.git']
        if d == modules or d.startswith(modules + os.sep):
            if 'SKILL.md' in files:
                errors.append(f'{d}: SKILL.md inside _modules/')
            continue
        if 'SKILL.md' not in files:
            continue
        text = open(os.path.join(d, 'SKILL.md'), encoding='utf-8').read()
        m = re.match(r'---\n(.*?)\n---\n', text, re.S)
        if not m:
            errors.append(f'{d}: no frontmatter')
            continue
        fm = m.group(1)
        name = (re.search(r'^name:\s*(.+)$', fm, re.M) or [None, None])[1]
        raw = (re.search(r'^description:\s*(.+)$', fm, re.M) or [None, ''])[1].strip()
        desc = json.loads(raw) if raw.startswith('"') else raw.strip("'")
        folder = os.path.basename(d)
        rel = os.path.relpath(d, root).split(os.sep)
        project = rel[0] == 'Projects'
        if name != folder:
            errors.append(f'{d}: name {name!r} != folder {folder!r}')
        if not desc or desc in ('>', '>-', '|', '|-'):
            errors.append(f'{d}: description missing or multi-line')
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
        for link in LINK_REF.findall(text):
            if '<' in link or '…' in link:
                continue
            if not os.path.exists(os.path.realpath(os.path.join(d, link))):
                errors.append(f'{d}: dead link {link}')
        if RETIRED.search(text):
            errors.append(f'{d}: retired core link or numbered Module section')
        if sum(1 for line in text.splitlines() if line.lstrip().startswith('`' * 3)) % 2:
            warnings.append(f'{d}: odd number of code fences (unclosed block)')
        if name == folder:
            project_dir = os.path.dirname(d)
            link = (not project) or folder.endswith('-profile') or folder in read_list(os.path.join(project_dir, '.flat-links'))
            skills[folder] = {'path': d, 'project': rel[1] if project else None, 'link': link}
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


def plan_links(root, flat, skills, agents_dir=None, agents_skills=None):
    """Return the link changes needed, as (action, name, target) tuples, plus untouched foreign dead links."""
    actions, foreign_dead = [], []
    combined = dict(agents_skills or {})
    combined.update(skills)

    if is_monolithic_symlink(flat, root):
        for name, meta in sorted(combined.items()):
            if meta['link']:
                actions.append(('create', name, meta['path']))
        return actions, foreign_dead

    if os.path.isdir(flat):
        for item in sorted(os.listdir(flat)):
            p = os.path.join(flat, item)
            if not os.path.islink(p):
                continue
            target = os.path.normpath(os.path.join(flat, os.readlink(p)))
            if not os.path.exists(p):
                if target.startswith(root + os.sep) or (agents_dir and target.startswith(agents_dir + os.sep)):
                    actions.append(('prune', item, target))
                else:
                    foreign_dead.append(f'{item} -> {target}')
            elif target.startswith(os.path.join(root, 'Projects') + os.sep) and item in skills and not skills[item]['link']:
                actions.append(('unlink', item, target))
    for name, meta in sorted(combined.items()):
        if not meta['link']:
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
            for n in missing:
                warnings.append(f'{project} @ {ws}: {n} is neither linked nor shipped in a repo skill loader (.claude/skills, .agents/skills, or .gemini/skills), so hosts cannot load it there (add it to Projects/{project}/.flat-links, or retire it)')
            cfg = os.path.join(path, '.agents', 'skills.json')
            if not os.path.isfile(cfg):
                lines.append(f'{project} @ {ws}: no .agents/skills.json (Antigravity not configured)')
                continue
            try:
                entries = [os.path.realpath(os.path.expanduser(e['path'])) for e in json.load(open(cfg, encoding='utf-8')).get('entries', [])]
            except (ValueError, KeyError, TypeError, AttributeError) as e:
                warnings.append(f'{cfg}: unreadable ({e})')
                continue
            for e in entries:
                if not os.path.isdir(e):
                    warnings.append(f'{cfg}: entry {e} does not exist')
            if root not in entries:
                warnings.append(f'{cfg}: general skills not listed, add {{"path": "{root}"}}')
            covered = os.path.join(projects_dir, project) in entries or any(
                os.path.basename(e) == 'skills' and os.path.basename(os.path.dirname(e)) in ('.claude', '.agents', '.gemini') for e in entries)
            if not covered:
                warnings.append(f'{cfg}: no entry loads the {project} skills (the registry folder or a repo skills dir)')
            lines.append(f'{project} @ {ws}: host loaders {len(held) - len(missing)}/{len(held)} held-out skills shipped by the repo · .agents/skills.json {len(entries)} entries')
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
            warnings.append(f'{cfg}: ~/.agents/skills not listed, add {{"path": "{os.path.realpath(agents_dir)}"}}')
    return warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--apply', action='store_true', help='fix the loader links (default: report only)')
    parser.add_argument('--registry', help='registry root (default: the folder above this script)')
    parser.add_argument('--targets', help='comma-separated loader targets to sync (default: claude,antigravity,gemini)')
    args = parser.parse_args()

    root = os.path.realpath(args.registry or os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
    agents_dir = os.path.expanduser(os.path.join('~', '.agents', 'skills'))

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

    if args.apply:
        for target_name, target_path in targets.items():
            sanitize_target_dir(target_path, root)

    target_actions = {}
    target_foreign = {}
    target_failed = {}

    for target_name, target_path in targets.items():
        actions, foreign_dead = plan_links(root, target_path, skills, agents_dir, agents_skills)
        target_actions[target_name] = actions
        target_foreign[target_name] = foreign_dead
        if args.apply:
            target_failed[target_name] = apply_links(target_path, actions)
        else:
            target_failed[target_name] = []

    ws_lines, ws_warnings = check_workspaces(root, skills)
    warnings += ws_warnings + check_global_antigravity(agents_dir, targets)

    general = sum(m['project'] is None for m in skills.values())
    print(f'registry: {root}')
    print(f'skills: {len(skills)} (general {general}, project {len(skills) - general}) · ~/.agents/skills: {len(agents_skills)} linked, {len(agents_shadowed)} shadowed · {len(errors)} errors · {len(warnings)} warnings')
    held = sorted(n for n, m in skills.items() if not m['link'])
    print(f'held out (project skills not in .flat-links): {len(held)}')
    if agents_shadowed:
        print(f'shadowed in ~/.agents/skills (registry wins): {len(agents_shadowed)}  {", ".join(agents_shadowed)}')

    for target_name, target_path in targets.items():
        rel_target = target_path.replace(os.path.expanduser('~'), '~')
        status_suffix = "applied" if args.apply else "check only (--apply to change)"
        if not args.apply and is_monolithic_symlink(target_path, root):
            status_suffix += " (monolithic symlink -> registry root, --apply to convert)"
        print(f'{target_name} ({rel_target}): {status_suffix}')
        for action in ('create', 'repoint', 'prune', 'unlink'):
            names = [n for a, n, _ in target_actions[target_name] if a == action]
            print(f'  {action}: {len(names)}' + (f'  {", ".join(names)}' if names else ''))
        for label, items in [('left alone', target_foreign[target_name]), ('FAILED', target_failed[target_name])]:
            if items:
                print(f'  {label}: {len(items)}')
                for i in items:
                    print(f'    - {i}')

    print('workspaces:')
    for line in ws_lines:
        print(f'  {line}')
    for label, items in [('ERRORS', errors), ('warnings', warnings)]:
        print(f'{label}: {len(items)}')
        for i in items:
            print(f'  - {i.replace(root + os.sep, "")}')
    any_failed = any(target_failed.values())
    sys.exit(1 if errors or any_failed else 0)


if __name__ == '__main__':
    main()
