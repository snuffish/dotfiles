#!/bin/bash
# Session data for antigravity-resume (code.bash):
#   sessions.sh list here|all [TEXT] [subagents]
#       One row per session, newest first:
#       "<age>\t<short id>\t<branch>\t<label>\t<id>\t<file>\t<cwd>"
#   sessions.sh preview FILE_OR_ID
#       Prose and tool calls styled with ANSI colors.
#   sessions.sh key scope|mode|subagent|change
#       fzf action for keys / query change.

cli_dir="$HOME/.gemini/antigravity-cli"
db_path="$cli_dir/conversation_summaries.db"
presence_dir="$cli_dir/presence"
brain_dir="$cli_dir/brain"

# ------------------------------------------------------------------------------
# 1. Preview Mode: Text Search Snippets
# ------------------------------------------------------------------------------
if [[ "$1" == preview && "$FZF_PROMPT" == *text* && -n "$FZF_QUERY" ]]; then
  if [[ -f "$2" ]]; then
    jq -c --arg q "$FZF_QUERY" '
      ($q | ascii_downcase) as $lq
      | select((.type == "USER_INPUT" or .type == "PLANNER_RESPONSE") and (.status == "DONE" or .status == null))
      | .type as $raw_type | .created_at as $ts
      | {
          role: (if $raw_type == "USER_INPUT" then "user" else "assistant" end),
          ts: $ts,
          text: (
            if $raw_type == "USER_INPUT" then
              (.content
               | gsub("<ADDITIONAL_METADATA>[\\s\\S]*?</ADDITIONAL_METADATA>"; "")
               | gsub("<USER_SETTINGS_CHANGE>[\\s\\S]*?</USER_SETTINGS_CHANGE>"; "")
               | gsub("<USER_REQUEST>\\s*"; "")
               | gsub("</USER_REQUEST>\\s*"; "")
               | gsub("^\\s+|\\s+$"; ""))
            else
              (if .content and .content != "" then .content
               elif .tool_calls and (.tool_calls | length) > 0 then
                 "⚙ Tool: " + (.tool_calls | map(.name + (if .args.toolSummary then " (" + .args.toolSummary + ")" else "" end)) | join(", "))
               elif .thinking and .thinking != "" then
                 "💭 " + (.thinking | .[0:200]) + "…"
               else "" end)
            end
          )
        }
      | select((.text | type) == "string" and (.text | ascii_downcase | contains($lq)))' "$2" | tail -n 20 \
    | jq -rn --arg q "$FZF_QUERY" '
      def style($code): "\u001b[\($code)m\(.)\u001b[0m";
      ($q | gsub("(?<c>[.*+?^${}()|\\[\\]\\\\/-])"; "\\\(.c)")) as $re
      | [inputs] | "\(length) message\(if length == 1 then "" else "s" end) mention" + (if length == 1 then "s " else " " end) + ($q | style("1")) + "\n",
        (.[] | (.text | [match($re; "i")][0].offset) as $at
          | (if .role == "user" then "❯ You" | style("1;36") else "● Antigravity" | style("1;32") end)
            + "  " + (.ts | sub("\\.[0-9]+Z$"; "Z") | fromdate | localtime | strftime("%Y-%m-%d %H:%M") | style("2")),
            ((if $at > 200 then "…" else "" end) + .text[([$at - 200, 0] | max):$at + 400] + (if (.text | length) > $at + 400 then "…" else "" end)
             | gsub("(?<m>\($re))"; "\(.m)" | style("1;30;43"); "i")), "")'
    exit 0
  fi
fi

# ------------------------------------------------------------------------------
# 2. Preview Mode: Prose & Tool Calls
# ------------------------------------------------------------------------------
if [[ "$1" == preview ]]; then
  file="$2"
  if [[ -f "$file" ]]; then
    jq -c '
      select((.type == "USER_INPUT" or .type == "PLANNER_RESPONSE") and (.status == "DONE" or .status == null))
      | {
          role: (if .type == "USER_INPUT" then "user" else "assistant" end),
          ts: .created_at,
          text: (
            if .type == "USER_INPUT" then
              (.content
               | gsub("<ADDITIONAL_METADATA>[\\s\\S]*?</ADDITIONAL_METADATA>"; "")
               | gsub("<USER_SETTINGS_CHANGE>[\\s\\S]*?</USER_SETTINGS_CHANGE>"; "")
               | gsub("<USER_REQUEST>\\s*"; "")
               | gsub("</USER_REQUEST>\\s*"; "")
               | gsub("^\\s+|\\s+$"; ""))
            else
              (if .content and .content != "" then .content
               elif .tool_calls and (.tool_calls | length) > 0 then
                 "⚙ Tool: " + (.tool_calls | map(.name + (if .args.toolSummary then " (" + .args.toolSummary + ")" else "" end)) | join(", "))
               elif .thinking and .thinking != "" then
                 "💭 " + (.thinking | .[0:200]) + "…"
               else "" end)
            end
          )
        }
      | select(.text != "")' "$file" | tail -n 30 \
    | jq -rn '
      def style($code): "\u001b[\($code)m\(.)\u001b[0m";
      foreach inputs as $m ({}; {role: $m.role, new: (.role != $m.role)}; $m + {new: .new})
      | (if .new then
           "\n" + (if .role == "user" then "❯ You" | style("1;36") else "● Antigravity" | style("1;32") end)
           + "  " + (.ts | sub("\\.[0-9]+Z$"; "Z") | fromdate | localtime | strftime("%Y-%m-%d %H:%M") | style("2"))
         else "" end),
        (if (.text | length) > 1500 then .text[0:1500] + " …" else .text end)' \
    | tail -n +2 \
    | sed -E -e '/^```/,/^```/{' -e $'s/.*/\e[32m&\e[39m/' -e b -e '}' \
        -e $'s/\\*\\*([^*]+)\\*\\*/\e[1m\\1\e[22m/g' -e $'s/`([^`]+)`/\e[33m\\1\e[39m/g' -e $'s/^(#+ .*)$/\e[1;35m\\1\e[0m/'
    exit 0
  fi

  # Fallback: query summary from SQLite if transcript file is missing
  cid="${file##*/}"; cid="${cid%.*}"
  if [[ -f "$db_path" ]]; then
    sqlite3 -batch -noheader "file:$db_path?mode=ro" -cmd ".timeout 2000" \
      "SELECT title, preview, last_modified_time, step_count FROM conversation_summaries WHERE conversation_id = '$cid';" 2>/dev/null \
    | while IFS='|' read -r title prev mtime steps; do
        printf '\e[1;32m● Antigravity\e[0m  \e[2m%s\e[0m\n\n' "$mtime"
        printf '\e[1m%s\e[0m (%s steps)\n\n' "$title" "$steps"
        [[ -n "$prev" ]] && printf '%s\n\n' "$prev"
        printf '\e[2m(Detailed transcript is not archived for this session)\e[0m\n'
      done
    exit 0
  fi
  exit 0
fi

# ------------------------------------------------------------------------------
# 3. Key Navigation & Toggle Actions
# ------------------------------------------------------------------------------
if [[ "$1" == key ]]; then
  scope=here; [[ "$FZF_PROMPT" == All* ]] && scope=all
  text=; [[ "$FZF_PROMPT" == *text* ]] && text=1
  sub=; [[ "$FZF_PROMPT" == *+sub* ]] && sub=1
  case "$2" in
    scope) if [[ $scope == all ]]; then scope=here; else scope=all; fi ;;
    mode) if [[ $text ]]; then text=; else text=1; fi ;;
    subagent) if [[ $sub ]]; then sub=; else sub=1; fi ;;
    # Fuzzy mode can't search the hidden full id: a pasted session id searches its 8-char short id
    change) [[ $text ]] || { [[ "$FZF_QUERY" =~ ^([0-9a-fA-F]{8})-[0-9a-fA-F-]*$ ]] && echo "search(${BASH_REMATCH[1]})"; exit 0; } ;;
  esac
  label='This dir'; [[ $scope == all ]] && label=All
  [[ $sub ]] && label="$label+sub"
  sub_arg="${sub:-0}"
  if [[ $text ]]; then
    echo "change-prompt($label text> )+disable-search+reload(bash $0 list $scope {q} $sub_arg)+refresh-preview"
  else
    echo "change-prompt($label> )+enable-search+reload(bash $0 list $scope '' $sub_arg)+refresh-preview"
  fi
  exit 0
fi

# ------------------------------------------------------------------------------
# 4. List Mode: SQLite Fast Extraction
# ------------------------------------------------------------------------------
scope="${2:-here}"
query="$3"
show_subs="${4:-0}"

[[ -f "$db_path" ]] || exit 0

python3 -I -c '
import sqlite3, json, os, sys, time, subprocess, signal
from urllib.parse import unquote
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass

db_path = sys.argv[1]
presence_dir = sys.argv[2]
brain_dir = sys.argv[3]
scope = sys.argv[4]
query = sys.argv[5].strip().lower() if len(sys.argv) > 5 else ""
show_subs = sys.argv[6] == "1" if len(sys.argv) > 6 else False
cwd_filter = os.getcwd()
home = os.path.expanduser("~")

try:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.execute("PRAGMA busy_timeout = 2000")
    c = conn.cursor()
    c.execute("""
        SELECT conversation_id, title, preview, workspace_uris,
               CAST(strftime("%s", last_modified_time) AS INTEGER),
               status, parent_conversation_id
        FROM conversation_summaries
        ORDER BY last_modified_time DESC
    """)
    rows = c.fetchall()
except Exception:
    sys.exit(0)

# Pre-cache git branches by unique directory
branch_cache = {}
def get_branch(d):
    if not d or not os.path.isdir(d):
        return ""
    if d in branch_cache:
        return branch_cache[d]
    p = d
    while p and p != "/" and p != home:
        if os.path.exists(os.path.join(p, ".git")):
            break
        p = os.path.dirname(p)
    if not p or p == "/" or p == home:
        branch_cache[d] = ""
        return ""
    if p in branch_cache:
        branch_cache[d] = branch_cache[p]
        return branch_cache[p]
    try:
        res = subprocess.run(["git", "-C", p, "branch", "--show-current"], capture_output=True, text=True, timeout=0.2)
        b = res.stdout.strip()
        branch_cache[p] = b
        branch_cache[d] = b
        return b
    except Exception:
        branch_cache[d] = ""
        return ""

now = int(time.time())

out_rows = []
for cid, title, prev, uris_raw, mtime, status, parent in rows:
    if not show_subs and parent != "":
        continue
    uris = json.loads(uris_raw) if uris_raw else []
    raw_cwd = uris[0] if uris else ""
    cwd = unquote(raw_cwd.replace("file://", "")) if raw_cwd.startswith("file://") else raw_cwd

    if scope == "here" and cwd and not cwd_filter.startswith(cwd) and not cwd.startswith(cwd_filter):
        continue

    transcript = os.path.join(brain_dir, cid, ".system_generated", "logs", "transcript.jsonl")

    # If full text query provided, check transcript or title/preview
    if query:
        matched = False
        if query in (title or "").lower() or query in (prev or "").lower():
            matched = True
        elif os.path.isfile(transcript):
            try:
                with open(transcript, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        if query in line.lower():
                            matched = True
                            break
            except Exception:
                pass
        if not matched:
            continue

    age_sec = max(0, now - (mtime or now))
    if age_sec < 60:
        age_str = "now"
    elif age_sec < 3600:
        age_str = f"{age_sec // 60}m ago"
    elif age_sec < 86400:
        age_str = f"{age_sec // 3600}h ago"
    elif age_sec < 604800:
        age_str = f"{age_sec // 86400}d ago"
    else:
        age_str = time.strftime("%Y-%m-%d", time.localtime(mtime or now))

    # Dot if modified in last 2 minutes
    dot = "\033[32m●\033[0m " if age_sec < 120 else "  "
    age_col = f"{dot}{age_str:<8}"
    id_col = f"\033[90m{cid[:8]}\033[0m"

    branch = get_branch(cwd)

    display_title = (title or prev or "Untitled conversation").strip().replace("\t", " ")

    prefix = ""
    if scope == "all" and cwd:
        disp_cwd = cwd.replace(home, "~")
        prefix = f"\033[34m{disp_cwd}\033[0m  "
    if parent != "":
        prefix += "\033[33m↳ subagent\033[0m "

    label_col = f"{prefix}{display_title}"
    out_rows.append((age_col, id_col, branch, label_col, cid, transcript, cwd or cwd_filter))

# fzf only searches what it shows, so the branch column fits the longest name instead of cutting it
bw = max((len(r[2]) for r in out_rows), default=0)
for age_col, id_col, branch, label_col, cid, transcript, cwd in out_rows:
    print(f"{age_col}\t{id_col}\t\033[35m{branch:<{bw}}\033[0m\t{label_col}\t{cid}\t{transcript}\t{cwd}")
' "$db_path" "$presence_dir" "$brain_dir" "$scope" "$query" "$show_subs"
