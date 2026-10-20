"""Create one tracker ticket (Azure DevOps work item or GitHub issue) from a spec file.

Usage:
  python3 -I create_ticket.py spec.json            # dry run: validates the spec, prints every field, runs nothing
  python3 -I create_ticket.py spec.json --create   # create it, add the parent link if any, print id and URL

spec.json:
  {
    "host": "ado" | "github",
    "ado":    {"org": "https://dev.azure.com/<org>", "project": "<project>"},
    "github": {"repo": "<owner>/<name>"},
    "type": "User Story",                              # ADO only: User Story | Task | Bug | Feature | ...
    "title": "...",
    "area": "<AreaPath>",                              # ADO, optional
    "iteration": "<IterationPath>",                    # ADO, optional
    "tags": ["Backend"],                               # ADO System.Tags / GitHub labels, optional
    "parent": 31172,                                   # ADO, optional
    "fields": {"Microsoft.VSTS.Common.Priority": 2},   # ADO, optional extra fields
    "description_file": "description.html",           # ADO System.Description
    "acceptance_file": "acceptance.html",              # ADO Microsoft.VSTS.Common.AcceptanceCriteria
    "repro_file": "repro.html",                        # ADO Bug: Microsoft.VSTS.TCM.ReproSteps
    "body_file": "body.md"                             # GitHub issue body
  }

File paths resolve relative to spec.json.
"""
import json
import os
import subprocess
import sys
from urllib.parse import quote


def load_spec(path):
    with open(path, encoding="utf-8") as f:
        spec = json.load(f)
    return spec, os.path.dirname(os.path.abspath(path))


def read(base, name):
    with open(os.path.join(base, name), encoding="utf-8") as f:
        text = f.read().strip()
    if not text:
        sys.exit(f"{name} is empty")
    return text


def validate(spec):
    host = spec.get("host")
    if host not in ("ado", "github"):
        sys.exit('host must be "ado" or "github"')
    if not spec.get("title"):
        sys.exit("title is required")
    if host == "ado":
        if not spec.get("type"):
            sys.exit("type is required for ado")
        org = spec.get("ado", {}).get("org", "")
        if not (org.startswith("https://dev.azure.com/") or (org.startswith("https://") and org.rstrip("/").endswith(".visualstudio.com"))):
            sys.exit("ado.org must be https://dev.azure.com/<org> or https://<org>.visualstudio.com (pr-host › Organization URL)")
        if spec["type"] == "Task" and not spec.get("parent"):
            print("warning: a Task without a parent; most boards expect tasks under a story")
    if host == "github" and not spec.get("body_file"):
        sys.exit("body_file is required for github")
    return host


def ado_commands(spec, base):
    cfg = spec["ado"]
    create = ["az", "boards", "work-item", "create", "--org", cfg["org"], "--project", cfg["project"],
              "--type", spec["type"], "--title", spec["title"]]
    if spec.get("area"):
        create += ["--area", spec["area"]]
    if spec.get("iteration"):
        create += ["--iteration", spec["iteration"]]
    if spec.get("description_file"):
        create += ["--description", read(base, spec["description_file"])]
    fields = [f"{name}={value}" for name, value in (spec.get("fields") or {}).items()]
    if spec.get("acceptance_file"):
        fields.append("Microsoft.VSTS.Common.AcceptanceCriteria=" + read(base, spec["acceptance_file"]))
    if spec.get("repro_file"):
        fields.append("Microsoft.VSTS.TCM.ReproSteps=" + read(base, spec["repro_file"]))
    if spec.get("tags"):
        fields.append("System.Tags=" + "; ".join(spec["tags"]))
    if fields:
        create += ["--fields", *fields]
    create += ["--query", "id", "-o", "tsv"]
    return create


def github_command(spec, base):
    command = ["gh", "issue", "create", "--repo", spec["github"]["repo"], "--title", spec["title"],
               "--body-file", os.path.join(base, spec["body_file"])]
    for label in spec.get("tags") or []:
        command += ["--label", label]
    return command


def shown(argv):
    return [a if len(a) <= 100 else f"<{len(a)} chars>" for a in argv]


def run(argv):
    result = subprocess.run(argv, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"FAILED: {result.stderr.strip()}")
        sys.exit(1)
    return result.stdout.strip()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    spec, base = load_spec(sys.argv[1])
    host = validate(spec)
    create = "--create" in sys.argv

    command = ado_commands(spec, base) if host == "ado" else github_command(spec, base)
    print(f"{host}: {spec.get('type', 'issue')} · {spec['title']}")
    for key in ("area", "iteration", "tags", "parent", "fields"):
        if spec.get(key):
            print(f"  {key}: {spec[key]}")
    print("  command:", " ".join(shown(command)))
    if not create:
        print("Dry run only. Re-run with --create to file it.")
        return

    output = run(command)
    if host == "github":
        print(f"created {output}")
        return
    item_id = output
    cfg = spec["ado"]
    if spec.get("parent"):
        run(["az", "boards", "work-item", "relation", "add", "--org", cfg["org"], "--id", item_id,
             "--relation-type", "parent", "--target-id", str(spec["parent"]), "-o", "none"])
        print(f"  parent #{spec['parent']} linked")
    print(f"created #{item_id} {cfg['org'].rstrip('/')}/{quote(cfg['project'])}/_workitems/edit/{item_id}")


if __name__ == "__main__":
    main()
