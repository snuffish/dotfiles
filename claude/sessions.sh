#!/bin/bash
# Session data for claude-resume (claude.bash):
#   sessions.sh list here|all   one row per session, newest first: "<time>\t<id>\t<label>\t<file>\t<cwd>"
#   sessions.sh preview FILE    the session's last 40 messages
# Transcripts can be large, so list greps out the few lines it needs instead of parsing every file with jq

projects="$HOME/.claude/projects"

if [[ "$1" == preview ]]; then
  jq -r 'select(.type == "user" or .type == "assistant") | .message.content
    | if type == "array" then map(.text? // empty) | join(" ") else . end
    | select(type == "string" and length > 0) | "• " + .[0:400]' "$2" | tail -n 40
  exit
fi

if [[ "$2" == all ]]; then
  files=("$projects"/*/*.jsonl)
else
  files=("$projects/${PWD//[^[:alnum:]]/-}"/*.jsonl)
fi
[[ -e "${files[0]}" ]] || exit 0

# ripgrep when installed: BSD grep takes seconds per pass over a gigabyte of transcripts
if command -v rg >/dev/null; then
  search() { rg --no-config -H -N --no-heading "$@"; }
else
  search() { grep -H "$@"; }
fi

# "<tag>\t<file>\t<value>" lines: m = modified time, c = working directory, t = title, p = user prompt
{
  if stat -c %Y / >/dev/null 2>&1; then
    stat -c $'m\t%n\t%Y' "${files[@]}"
  else
    stat -f $'m\t%N\t%m' "${files[@]}"
  fi
  search -m1 -o '"cwd":"[^"]*"' "${files[@]}" | sed 's/\.jsonl:/.jsonl\t/; s/^/c\t/'
  search -F -e '"type":"custom-title"' -e '"type":"ai-title"' "${files[@]}" | sed 's/\.jsonl:/.jsonl\t/; s/^/t\t/'
  # Untitled sessions fall back to their first prompt
  search -m5 -F '"role":"user","content":"' "${files[@]}" | sed 's/\.jsonl:/.jsonl\t/; s/^/p\t/'
} | jq -Rrn --arg scope "$2" --arg home "$HOME" '
  reduce (inputs | split("\t")) as [$tag, $f, $v] ({};
    if $tag == "m" then .[$f].time = ($v | tonumber)
    elif $tag == "c" then .[$f].cwd = ("{\($v)}" | fromjson | .cwd)
    elif $tag == "t" then ($v | fromjson) as $j | .[$f] += (if $j.customTitle then {custom: $j.customTitle} else {ai: $j.aiTitle} end)
    elif .[$f].prompt then .
    else ($v | fromjson) as $j | ($j.message.content) as $c
      | if ($j.isMeta | not) and ($c | type) == "string" and $c != "" and ($c | startswith("<") | not)
        then .[$f].prompt = $c else . end
    end)
  | to_entries | map(.value + {file: .key, title: (.value.custom // .value.ai // .value.prompt)})
  | map(select(.title and .time)) | sort_by(-.time)[]
  | (.title | .[0:300] | gsub("\\s+"; " ") | .[0:100]) as $title
  | [ (.time | localtime | strftime("%Y-%m-%d %H:%M")),
      (.file | split("/") | last | rtrimstr(".jsonl")),
      (if $scope == "all" then "\(.cwd // "?" | sub("^\($home)"; "~"))  \($title)" else $title end),
      .file, .cwd // "" ] | @tsv
'
