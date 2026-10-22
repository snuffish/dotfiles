"""Post drafted PR feedback (inline threads, thread replies, general comments) to Azure DevOps or GitHub.

Usage (run in place; payload files are written beside spec.json):
  python3 -I <skill-dir>/scripts/post_pr_comments.py <dir>/spec.json                     # dry run: writes payload-<key>.json, prints anchors
  python3 -I <skill-dir>/scripts/post_pr_comments.py <dir>/spec.json --post              # post every item
  python3 -I <skill-dir>/scripts/post_pr_comments.py <dir>/spec.json --post --only 6,7   # post a subset (post one, verify, then the rest)

spec.json:
  {
    "host": "ado" | "github",
    "ado":    {"org": "https://dev.azure.com/<org>", "project": "<p>", "repo": "<name-or-guid>", "pr": 123, "iteration": 1},
    "github": {"repo": "<owner>/<name>", "pr": 123, "commit": "<head sha>"},
    "items": [
      {"key": "6", "kind": "thread", "path": "/src/Foo.cs", "start": 122, "end": 125, "end_offset": 117,
       "change_tracking_id": 10, "body": "**🟡 ...**"},
      {"key": "r1", "kind": "reply", "thread_id": 110776, "body_file": "reply-r1.md"},
      {"key": "g1", "kind": "general", "body": "..."}
    ]
  }

"body_file" is resolved relative to spec.json. "end_offset" and "change_tracking_id" are Azure DevOps only;
GitHub ignores them and anchors on the RIGHT side of "commit".
"""
import json
import os
import subprocess
import sys


def load_spec(path):
    with open(path, encoding="utf-8") as f:
        spec = json.load(f)
    base = os.path.dirname(os.path.abspath(path))
    for item in spec["items"]:
        if "body_file" in item:
            with open(os.path.join(base, item["body_file"]), encoding="utf-8") as f:
                item["body"] = f.read().strip()
    return spec, base


def ado_payload(item, iteration):
    if item["kind"] == "reply":
        return {"content": item["body"], "parentCommentId": 1, "commentType": 1}
    body = {"comments": [{"parentCommentId": 0, "content": item["body"], "commentType": 1}], "status": 1}
    if item["kind"] == "thread":
        body["threadContext"] = {
            "filePath": item["path"],
            "rightFileStart": {"line": item["start"], "offset": 1},
            "rightFileEnd": {"line": item["end"], "offset": item["end_offset"]},
        }
        body["pullRequestThreadContext"] = {
            "changeTrackingId": item["change_tracking_id"],
            "iterationContext": {"firstComparingIteration": iteration, "secondComparingIteration": iteration},
        }
    return body


def ado_command(cfg, item, payload_path):
    route = [f"project={cfg['project']}", f"repositoryId={cfg['repo']}", f"pullRequestId={cfg['pr']}"]
    resource = "pullRequestThreads"
    if item["kind"] == "reply":
        resource = "pullRequestThreadComments"
        route.append(f"threadId={item['thread_id']}")
    return [
        "az", "devops", "invoke", "--org", cfg["org"], "--area", "git", "--resource", resource,
        "--route-parameters", *route, "--http-method", "POST", "--in-file", payload_path,
        "--api-version", "7.1", "--query", "id", "-o", "tsv",
    ]


def github_payload(item, commit):
    if item["kind"] != "thread":
        return {"body": item["body"]}
    body = {"body": item["body"], "commit_id": commit, "path": item["path"].lstrip("/"),
            "line": item["end"], "side": "RIGHT"}
    if item["start"] != item["end"]:
        body.update(start_line=item["start"], start_side="RIGHT")
    return body


def github_command(cfg, item, payload_path):
    repo, pr = cfg["repo"], cfg["pr"]
    endpoint = {
        "thread": f"repos/{repo}/pulls/{pr}/comments",
        "reply": f"repos/{repo}/pulls/{pr}/comments/{item.get('thread_id')}/replies",
        "general": f"repos/{repo}/issues/{pr}/comments",
    }[item["kind"]]
    return ["gh", "api", endpoint, "--method", "POST", "--input", payload_path, "--jq", ".id"]


def describe(item):
    if item["kind"] == "thread":
        return f"thread  {item['path']}:{item['start']}-{item['end']}"
    if item["kind"] == "reply":
        return f"reply   -> thread {item['thread_id']}"
    return "general"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    spec, base = load_spec(sys.argv[1])
    post = "--post" in sys.argv
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))

    host = spec["host"]
    cfg = spec[host]
    for item in spec["items"]:
        if only is not None and item["key"] not in only:
            continue
        payload = ado_payload(item, cfg.get("iteration")) if host == "ado" else github_payload(item, cfg.get("commit"))
        payload_path = os.path.join(base, f"payload-{item['key']}.json")
        with open(payload_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        print(f"[{item['key']}] {describe(item)}")
        if not post:
            continue
        command = ado_command(cfg, item, payload_path) if host == "ado" else github_command(cfg, item, payload_path)
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"    FAILED: {result.stderr.strip()}")
            sys.exit(1)
        print(f"    posted id {result.stdout.strip()}")
    if not post:
        print("Dry run only. Re-run with --post to create them.")


if __name__ == "__main__":
    main()
