#!/usr/bin/env python3
"""Read-only lookups in the GR.PRIIS source for writing production SQL by hand.

  table <entity-or-table>...         SQL table, columns and types from the EF model snapshot
  enum <EnumName>... [--case <col>]  enum values and Swedish display names; --case prints a T-SQL CASE
  notification <text>                notification definitions matching an id, display name or string
                                     literal (e.g. an email subject), with recipients query, ForRoles
                                     and the jobs that raise them

Run from anywhere inside the GR.PRIIS checkout, or pass --repo <path>.
"""
import argparse
import os
import re
import subprocess
import sys

SNAPSHOT = 'backend/source/GR.PRIIS.Library/DataAccess/Migrations/PriisDbContextModelSnapshot.cs'
SOURCE = 'backend/source'


def repo_root(given):
    if given:
        return os.path.abspath(os.path.expanduser(given))
    try:
        root = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        sys.exit('Not inside a git checkout; pass --repo <GR.PRIIS checkout>.')
    if not os.path.isfile(os.path.join(root, SNAPSHOT)):
        sys.exit(f'{root} is not a GR.PRIIS checkout ({SNAPSHOT} missing); pass --repo.')
    return root


def source_files(root):
    base = os.path.join(root, SOURCE)
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in ('bin', 'obj', 'Migrations') and not d.endswith('.Tests')]
        for name in filenames:
            if name.endswith('.cs'):
                yield os.path.join(dirpath, name)


def read(path):
    with open(path, encoding='utf-8-sig') as f:
        return f.read().splitlines()


def rel(root, path):
    return os.path.relpath(path, root)


# ---------- table ----------

ENTITY_START = re.compile(r'^(\s*)modelBuilder\.Entity\("([^"]+)", b =>')
PROPERTY = re.compile(r'^\s*b\.Property<([^>]+)>\("([^"]+)"\)')
TO_TABLE = re.compile(r'^\s*b\.ToTable\("([^"]+)"(?:, "([^"]+)")?')
TEMPORAL = re.compile(r'^\s*b\.ToTable\(tb => tb\.IsTemporal')
DISCRIMINATOR = re.compile(r'^\s*b\.HasDiscriminator')
BASE_TYPE = re.compile(r'^\s*b\.HasBaseType\("([^"]+)"\)')
COLUMN_NAME = re.compile(r'^\s*\.HasColumnName\("([^"]+)"\)')


def parse_snapshot(root):
    lines = read(os.path.join(root, SNAPSHOT))
    entities = {}
    current = last = None
    for no, line in enumerate(lines, 1):
        m = ENTITY_START.match(line)
        if m:
            current = entities.setdefault(m.group(2), {'columns': {}, 'table': None, 'temporal': False, 'line': no,
                                                       'discriminator': False, 'base': None})
            continue
        if current is None:
            continue
        if (p := PROPERTY.match(line)):
            last = p.group(2)
            current['columns'].setdefault(last, p.group(1))
        elif (c := COLUMN_NAME.match(line)) and last and c.group(1) != last:
            current['columns'][last] += f' (column [{c.group(1)}])'
        elif (bt := BASE_TYPE.match(line)):
            current['base'] = bt.group(1)
        elif (t := TO_TABLE.match(line)):
            current['table'] = (t.group(2) or 'dbo', t.group(1))
            current['line'] = no
        elif TEMPORAL.match(line):
            current['temporal'] = True
        elif DISCRIMINATOR.match(line):
            current['discriminator'] = True
        if line.rstrip().endswith(';'):
            last = None
    return entities


def cmd_table(root, names):
    entities = parse_snapshot(root)
    found = False
    for wanted in names:
        w = wanted.lower()
        for full, e in entities.items():
            short = full.rsplit('.', 1)[-1].lower()
            table = e['table'][1].lower() if e['table'] else ''
            if w not in (short, table, full.lower()):
                continue
            found = True
            base = e
            while not base['table'] and base['base'] in entities:
                base = entities[base['base']]
            if e['table']:
                where = f"[{e['table'][0]}].[{e['table'][1]}]"
            elif base['table']:
                where = f"[{base['table'][0]}].[{base['table'][1]}] (TPH subtype of {e['base'].rsplit('.', 1)[-1]}: filter on its discriminator)"
            else:
                where = '(no own table: owned type)'
            flags = ', '.join(f for f, on in (('temporal: FOR SYSTEM_TIME ALL for history', e['temporal']),
                                              ('TPH discriminator', e['discriminator'])) if on)
            print(f"{full} -> {where}  ({SNAPSHOT}:{e['line']}){'  ' + flags if flags else ''}")
            for col, typ in e['columns'].items():
                print(f'    {col}: {typ}')
    if not found:
        sys.exit(f'No entity or table named {", ".join(names)} in the snapshot.')


# ---------- enum ----------

def find_enum(root, name):
    pattern = re.compile(rf'\benum\s+{re.escape(name)}\b')
    for path in source_files(root):
        lines = read(path)
        for i, line in enumerate(lines):
            if pattern.search(line):
                return path, i, lines
    return None


def parse_enum(lines, start):
    members, display, value, body = [], None, -1, False
    for no in range(start, len(lines)):
        line = lines[no].split('//', 1)[0].strip()
        if not body:
            body = '{' in line
            continue
        if line.startswith('}'):
            break
        if (d := re.search(r'Display\(Name\s*=\s*"([^"]*)"', line)):
            display = d.group(1)
        line = re.sub(r'\[[^\]]*\]', '', line).strip()
        for part in filter(None, (p.strip() for p in line.split(','))):
            m = re.match(r'^([A-Za-z_]\w*)\s*(?:=\s*(-?\d+))?$', part)
            if not m:
                continue
            value = int(m.group(2)) if m.group(2) else value + 1
            members.append((value, m.group(1), display, no + 1))
            display = None
    return members


def cmd_enum(root, names, case_column):
    for name in names:
        hit = find_enum(root, name)
        if not hit:
            sys.exit(f'enum {name} not found under {SOURCE}.')
        path, start, lines = hit
        members = parse_enum(lines, start)
        print(f'{name}  ({rel(root, path)}:{start + 1}) — stored as int')
        for value, member, display, _ in members:
            print(f'    {value} = {member}' + (f'  "{display}"' if display else ''))
        if case_column:
            print(f'\n    CASE {case_column}')
            for value, member, display, _ in members:
                label = (display or member).replace("'", "''")
                print(f"        WHEN {value} THEN N'{label}'")
            print(f"        ELSE CONCAT('?', {case_column}) END")
        print()


# ---------- notification ----------

STR_PROP = r'public string {0}\s*=>\s*\n?\s*"([^"]*)"'


def method_range(lines, start):
    depth, seen = 0, False
    for no in range(start, len(lines)):
        depth += lines[no].count('{') - lines[no].count('}')
        seen = seen or '{' in lines[no]
        if seen and depth <= 0:
            return start + 1, no + 1
    return start + 1, start + 1


def cmd_notification(root, text):
    t = text.lower()
    defs = []
    for path in source_files(root):
        content = '\n'.join(lines := read(path))
        if 'INotificationDefinition' not in content or 'INotificationHandler<' not in content:
            continue
        ident = re.search(STR_PROP.format('Id'), content)
        if not ident:
            continue
        literals = re.findall(r'"([^"]+)"', content)
        if not any(t in s.lower() for s in literals) and t not in os.path.basename(path).lower():
            continue
        defs.append((path, content, lines, ident.group(1)))
    if not defs:
        sys.exit(f'No notification definition mentions "{text}".')

    for path, content, lines, ident in defs:
        r = rel(root, path)
        display = re.search(STR_PROP.format('DisplayName'), content)
        roles = re.search(r'ForRoles\s*=>\s*\n?\s*\[([^\]]*)\]', content)
        handler = re.search(r'class\s+(\w+)\s*\(', content)
        print(f'{ident}  "{display.group(1) if display else "?"}"  ({r})')
        print(f'    ForRoles (settings rows only, not a recipient filter): {roles.group(1).replace("RoleType.", "").strip() if roles else "(none = every role)"}')
        for no, line in enumerate(lines):
            if 'GetRecipientUsersQuery(' in line and 'public' in line:
                a, b = method_range(lines, no)
                print(f'    Recipients: {r}:{a}-{b}')
                for body in lines[a - 1:b]:
                    print(f'      | {body.rstrip()}')
        for no, line in enumerate(lines, 1):
            if re.search(r'(Subject|Title)\s*=\s*\$?"', line) or re.search(r'\bemailSubject\s*=', line):
                print(f'    Subject/title: {r}:{no}: {line.strip()}')
        if handler:
            cls = handler.group(1)
            for other in source_files(root):
                if other == path:
                    continue
                olines = read(other)
                if not any(cls in l for l in olines):
                    continue
                cron = next(((i + 1, m.group(1)) for i, l in enumerate(olines)
                             if (m := re.search(r'TickerFunction\(.*cronExpression:\s*"([^"]+)"', l))), None)
                where = rel(root, other)
                if cron:
                    print(f'    Raised by job: {where}:{cron[0]}  cron "{cron[1]}" (sec min hour day month dow, UTC)')
                elif 'Program.cs' not in where and 'Setup' not in os.path.basename(where):
                    hits = [str(i + 1) for i, l in enumerate(olines) if cls in l][:3]
                    print(f'    Used by: {where}:{",".join(hits)}')
        print()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', help='GR.PRIIS checkout (default: the git root of the current directory)')
    sub = parser.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('table')
    p.add_argument('names', nargs='+')
    p = sub.add_parser('enum')
    p.add_argument('names', nargs='+')
    p.add_argument('--case', dest='case_column', help='also print a T-SQL CASE that decodes this column')
    p = sub.add_parser('notification')
    p.add_argument('text')
    args = parser.parse_args()
    if args.cmd == 'enum' and args.case_column and len(args.names) != 1:
        parser.error('--case decodes one column: pass exactly one enum with it')
    root = repo_root(args.repo)
    if args.cmd == 'table':
        cmd_table(root, args.names)
    elif args.cmd == 'enum':
        cmd_enum(root, args.names, args.case_column)
    else:
        cmd_notification(root, args.text)


if __name__ == '__main__':
    main()
