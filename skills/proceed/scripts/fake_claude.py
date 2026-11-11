#!/usr/bin/env python3
"""Stand-in for `claude -p` in test_run_plan.py: reads the prompt from stdin, acts on env switches, writes a session
transcript under RUN_PLAN_TRANSCRIPTS the way Claude Code does, and prints the JSON result.

FAKE_MISSING_JSON=<label>  the phase writes no phase json
FAKE_LEAK=<label>          the phase writes FAKE_LEAK_FILE (a global rule path) with the Write tool
FAKE_OTHER_FILE=<path>     the file changes during the phase without the phase writing it (another session)
FAKE_NO_TRANSCRIPT=1       no transcript is written
FAKE_FIX_WORKS=1           a FIX run creates fixed-<label>, which the stub gate script accepts
FAKE_VERIFY=<json>         the verifier's answer
"""
import json
import os
import sys
import uuid
from pathlib import Path

prompt = sys.stdin.read()
label = os.environ.get("RUN_PLAN_PHASE", "")
state = Path(os.environ["RUN_PLAN_STATE"])
sid = str(uuid.uuid4())
uses = []


def write(path, text):
    Path(path).write_text(text)
    uses.append({"type": "tool_use", "name": "Write", "input": {"file_path": str(Path(path).resolve())}})


def out(text):
    if os.environ.get("FAKE_NO_TRANSCRIPT") != "1" and os.environ.get("RUN_PLAN_TRANSCRIPTS"):
        folder = Path(os.environ["RUN_PLAN_TRANSCRIPTS"]) / "sim"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{sid}.jsonl").write_text(json.dumps({"type": "assistant", "message": {"content": uses}}) + "\n")
    print(json.dumps({"type": "result", "result": text, "session_id": sid, "total_cost_usd": 0.01, "is_error": False}))


if prompt.startswith("/proceed"):
    write(f"phase{label}.txt", "work\n")
    if os.environ.get("FAKE_MISSING_JSON") != label:
        write(state / f"phase-{label}.json", json.dumps({"commit_message": f"feat(sim): phase {label}", "caveats": [f"caveat {label}"]}))
    if os.environ.get("FAKE_LEAK") == label:
        write(os.environ["FAKE_LEAK_FILE"], "a new global rule\n")
    if os.environ.get("FAKE_OTHER_FILE"):
        Path(os.environ["FAKE_OTHER_FILE"]).write_text(str(uuid.uuid4()))
    out("phase done")
elif prompt.startswith("FIX"):
    if os.environ.get("FAKE_FIX_WORKS") == "1":
        write(f"fixed-{label}", "1")
    out("fixed")
elif "You verify one phase" in prompt:
    out(os.environ.get("FAKE_VERIFY", '{"missed_files":[],"scope_creep":[],"global_leaks":[],"summary":"ok"}'))
elif "Write the Friction part" in prompt:
    out("## Friction\n- simulated friction: propose a rule in the plan template")
else:
    out("unexpected prompt")
    sys.exit(1)
