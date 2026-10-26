"""Post drafted PR feedback (inline threads, thread replies, general comments) to Azure DevOps or GitHub.

Usage (run in place; payload files are written beside spec.json):
  python3 -I <skill-dir>/scripts/post_pr_comments.py <dir>/spec.json                     # dry run: writes payload-<key>.json, prints anchors
  python3 -I <skill-dir>/scripts/post_pr_comments.py <dir>/spec.json --post              # post every item
  python3 -I <skill-dir>/scripts/post_pr_comments.py <dir>/spec.json --post --only 6,7   # post a subset (post one, verify, then the rest)

spec.json: copy <skill-dir>/templates/spec.json to <dir>/spec.json, keep only the items you are posting and
replace every <placeholder>. The script refuses a spec whose active host block or selected items still hold one;
a "body" counts only when the whole body is a placeholder, so `List<T>` in a body is fine.

"host" is "ado" or "github"; only that host's block is read. "kind" is "thread", "reply" or "general".
"body_file" is resolved relative to spec.json. "end_offset" and "change_tracking_id" are Azure DevOps only;
GitHub ignores them and anchors on the RIGHT side of "commit".
"resolve" (replies only) sets the thread to Resolved once the reply is posted: Azure DevOps status "fixed",
GitHub resolveReviewThread on the review thread whose first comment is "thread_id".
"""
import json
import os
import re
import subprocess
import sys

PLACEHOLDER = re.compile(r"<[^<>\s]+>")


def load_spec(path):
    with open(path, encoding="utf-8") as f:
        spec = json.load(f)
    return spec, os.path.dirname(os.path.abspath(path))


def selected_items(spec, only):
    return [item for item in spec["items"] if only is None or item["key"] in only]


def find_placeholders(spec, items):
    host = spec["host"]
    found = [f"{host}.{field}" for field, value in spec[host].items()
             if isinstance(value, str) and PLACEHOLDER.search(value)]
    for item in items:
        for field, value in item.items():
            if not isinstance(value, str):
                continue
            match = PLACEHOLDER.fullmatch(value) if field == "body" else PLACEHOLDER.search(value)
            if match:
                found.append(f"{item['key']}.{field}")
    return found


def read_body_files(items, base):
    for item in items:
        if "body_file" in item:
            with open(os.path.join(base, item["body_file"]), encoding="utf-8") as f:
                item["body"] = f.read().strip()


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
        ct_id = item.get("change_tracking_id")
        if not ct_id:
            raise ValueError(f"Item {item.get('key')} is a 'thread' but missing 'change_tracking_id'; Azure DevOps requires this for inline comments. Use 'kind': 'general' instead.")
        body["pullRequestThreadContext"] = {
            "changeTrackingId": ct_id,
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


GITHUB_THREADS_QUERY = """
query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes { id comments(first: 1) { nodes { databaseId } } }
      }
    }
  }
}"""

GITHUB_RESOLVE_MUTATION = "mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }"


def run(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def resolve_ado(cfg, item, base):
    status_path = os.path.join(base, f"payload-{item['key']}-resolve.json")
    with open(status_path, "w", encoding="utf-8") as f:
        json.dump({"status": "fixed"}, f)
    route = [f"project={cfg['project']}", f"repositoryId={cfg['repo']}", f"pullRequestId={cfg['pr']}",
             f"threadId={item['thread_id']}"]
    return run([
        "az", "devops", "invoke", "--org", cfg["org"], "--area", "git", "--resource", "pullRequestThreads",
        "--route-parameters", *route, "--http-method", "PATCH", "--in-file", status_path,
        "--api-version", "7.1", "--query", "status", "-o", "tsv",
    ])


def resolve_github(cfg, item):
    owner, name = cfg["repo"].split("/", 1)
    pages = run(["gh", "api", "graphql", "--paginate", "-F", f"owner={owner}", "-F", f"name={name}",
                 "-F", f"pr={cfg['pr']}", "-f", f"query={GITHUB_THREADS_QUERY}",
                 "--jq", ".data.repository.pullRequest.reviewThreads.nodes[] | [.id, .comments.nodes[0].databaseId] | @tsv"])
    node_id = next((line.split("\t")[0] for line in pages.splitlines()
                    if line.split("\t")[1] == str(item["thread_id"])), None)
    if node_id is None:
        raise RuntimeError(f"no review thread starts with comment {item['thread_id']}")
    resolved = run(["gh", "api", "graphql", "-F", f"id={node_id}", "-f", f"query={GITHUB_RESOLVE_MUTATION}",
                    "--jq", ".data.resolveReviewThread.thread.isResolved"])
    return "resolved" if resolved == "true" else f"isResolved={resolved}"


def describe(item):
    if item["kind"] == "thread":
        return f"thread  {item['path']}:{item['start']}-{item['end']}"
    if item["kind"] == "reply":
        return f"reply   -> thread {item['thread_id']}" + (", then resolve" if item.get("resolve") else "")
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
    items = selected_items(spec, only)
    placeholders = find_placeholders(spec, items)
    if placeholders:
        print(f"Template placeholders left in the spec (replace them, or delete the item): {', '.join(placeholders)}")
        sys.exit(2)
    read_body_files(items, base)
    for item in items:
        if item.get("resolve") and item["kind"] != "reply":
            print(f"[{item['key']}] 'resolve' is only allowed on replies; new threads are posted active")
            sys.exit(2)
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
        if item.get("resolve"):
            try:
                status = resolve_ado(cfg, item, base) if host == "ado" else resolve_github(cfg, item)
            except RuntimeError as error:
                print(f"    reply posted, but RESOLVE FAILED: {error}")
                sys.exit(1)
            print(f"    thread {item['thread_id']} -> {status}")
    if not post:
        print("Dry run only. Re-run with --post to create them.")


if __name__ == "__main__":
    main()
