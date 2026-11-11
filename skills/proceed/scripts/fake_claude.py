#!/usr/bin/env python3
"""Stand-in for `claude -p` in test_run_plan.py: reads the prompt from stdin, acts on env switches, prints the JSON result.

FAKE_MISSING_JSON=<label>  the phase writes no phase json
FAKE_LEAK=<label>          the phase writes FAKE_LEAK_FILE (a global rule path)
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


def out(text):
    print(json.dumps({"type": "result", "result": text, "session_id": str(uuid.uuid4()), "total_cost_usd": 0.01, "is_error": False}))


if prompt.startswith("/proceed"):
    Path(f"phase{label}.txt").write_text("work\n")
    if os.environ.get("FAKE_MISSING_JSON") != label:
        (state / f"phase-{label}.json").write_text(json.dumps({"commit_message": f"feat(sim): phase {label}", "caveats": [f"caveat {label}"]}))
    if os.environ.get("FAKE_LEAK") == label:
        Path(os.environ["FAKE_LEAK_FILE"]).write_text("a new global rule\n")
    out("phase done")
elif prompt.startswith("FIX"):
    if os.environ.get("FAKE_FIX_WORKS") == "1":
        Path(f"fixed-{label}").write_text("1")
    out("fixed")
elif "You verify one phase" in prompt:
    out(os.environ.get("FAKE_VERIFY", '{"missed_files":[],"scope_creep":[],"global_leaks":[],"summary":"ok"}'))
elif "Write the Friction part" in prompt:
    out("## Friction\n- simulated friction: propose a rule in the plan template")
else:
    out("unexpected prompt")
    sys.exit(1)
