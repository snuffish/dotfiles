#!/bin/bash
# Session data for claude-resume (claude.bash):
#   sessions.sh list here|all [TEXT]  one row per session, newest first:
#                                     "<age>\t<short id>\t<branch>\t<label>\t<id>\t<file>\t<cwd>"
#                                     (colored, ● on an age = written in the last 2 minutes, likely still open;
#                                     fzf strips the colors from its output);
#                                     with TEXT, only sessions whose transcript contains it (literal, any case)
#   sessions.sh preview FILE          the session's last 30 messages, styled with ANSI colors; in text mode
#                                     ($FZF_PROMPT says "text"), the messages and tool calls that contain $FZF_QUERY
#   sessions.sh key scope|mode|change the fzf action for that key or query change; the prompt holds the state:
#                                     scope (This dir / All) and mode (fuzzy over titles / text in transcripts)
# Transcripts can be large, so list greps out the few lines it needs instead of parsing every file with jq

projects="$HOME/.claude/projects"

if [[ "$1" == preview && "$FZF_PROMPT" == *text* && -n "$FZF_QUERY" ]]; then
  # Every message, thinking block or tool call that contains the query (skill bodies aside: they repeat the command
  # line), the last 20 of them,
  # each cut to a window around its first hit with every hit highlighted
  jq -c --arg q "$FZF_QUERY" '
    ($q | ascii_downcase) as $lq
    | select((.type == "user" or .type == "assistant") and (.isMeta | not)) | .type as $role | .timestamp as $ts
    | .message.content | (if type == "array" then .[] else {type: "text", text: .} end)
    | {role: (if .type == "tool_use" or .type == "tool_result" then "tool" else $role end), ts: $ts,
       text: (if .type == "text" then .text
                | gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")
                | gsub("<command-message>[^<]*</command-message>\\s*"; "")
                | gsub("<command-name>(?<n>[^<]*)</command-name>\\s*(<command-args>(?<a>[\\s\\S]*?)</command-args>)?"; "\(.n) \(.a // "")")
              elif .type == "thinking" then .thinking
              elif .type == "tool_use" then "\(.name) \(.input | tostring)"
              elif .type == "tool_result" then .content | if type == "array" then map(.text? // empty) | join("\n") else tostring end
              else empty end)}
    | select((.text | type) == "string" and (.text | ascii_downcase | contains($lq)))' "$2" | tail -n 20 \
  | jq -rn --arg q "$FZF_QUERY" '
    def style($code): "\u001b[\($code)m\(.)\u001b[0m";
    ($q | gsub("(?<c>[.*+?^${}()|\\[\\]\\\\/-])"; "\\\(.c)")) as $re
    | [inputs] | "\(length) message\(if length == 1 then "" else "s" end) mention" + (if length == 1 then "s " else " " end) + ($q | style("1")) + "\n",
      (.[] | (.text | [match($re; "i")][0].offset) as $at
        | (if .role == "user" then "❯ You" | style("1;36") elif .role == "tool" then "⚙ Tool" | style("1;34") else "● Claude" | style("1;33") end)
          + "  " + (.ts | sub("\\.[0-9]+Z$"; "Z") | fromdate | localtime | strftime("%Y-%m-%d %H:%M") | style("2")),
          ((if $at > 200 then "…" else "" end) + .text[([$at - 200, 0] | max):$at + 400] + (if (.text | length) > $at + 400 then "…" else "" end)
           | gsub("(?<m>\($re))"; "\(.m)" | style("1;30;43"); "i")), "")'
  exit
fi

if [[ "$1" == preview ]]; then
  # Stream the conversation's prose (no skill bodies, tool calls or reminders), keep the last 30 messages,
  # then print them under a header per speaker turn
  jq -c 'select((.type == "user" or .type == "assistant") and (.isMeta | not))
    | {role: .type, ts: .timestamp, text: (.message.content
        | if type == "array" then map(.text? // empty) | join("\n") else . end
        | select(type == "string")
        | gsub("<system-reminder>[\\s\\S]*?</system-reminder>"; "")
        | gsub("<command-message>[^<]*</command-message>\\s*"; "")
        | gsub("<command-name>(?<n>[^<]*)</command-name>\\s*(<command-args>(?<a>[\\s\\S]*?)</command-args>)?"; "\(.n) \(.a // "")")
        | gsub("\\[Image: source: [^\\]]*\\]"; "")
        | gsub("^\\s+|\\s+$"; ""))}
    | select(.text != "")' "$2" | tail -n 30 \
  | jq -rn '
    def style($code): "\u001b[\($code)m\(.)\u001b[0m";
    foreach inputs as $m ({}; {role: $m.role, new: (.role != $m.role)}; $m + {new: .new})
    | (if .new then
         "\n" + (if .role == "user" then "❯ You" | style("1;36") else "● Claude" | style("1;33") end)
         + "  " + (.ts | sub("\\.[0-9]+Z$"; "Z") | fromdate | localtime | strftime("%Y-%m-%d %H:%M") | style("2"))
       else "" end),
      (if (.text | length) > 1500 then .text[0:1500] + " …" else .text end)' \
  | tail -n +2 \
  | sed -E -e '/^```/,/^```/{' -e $'s/.*/\e[32m&\e[39m/' -e b -e '}' \
      -e $'s/\\*\\*([^*]+)\\*\\*/\e[1m\\1\e[22m/g' -e $'s/`([^`]+)`/\e[33m\\1\e[39m/g' -e $'s/^(#+ .*)$/\e[1;35m\\1\e[0m/'
  exit
fi

if [[ "$1" == key ]]; then
  scope=here; [[ "$FZF_PROMPT" == All* ]] && scope=all
  text=; [[ "$FZF_PROMPT" == *text* ]] && text=1
  case "$2" in
    scope) if [[ $scope == all ]]; then scope=here; else scope=all; fi ;;
    mode) if [[ $text ]]; then text=; else text=1; fi ;;
    # Fuzzy mode filters inside fzf; text mode asks the transcripts again
    change) [[ $text ]] || exit 0 ;;
  esac
  label='This dir'; [[ $scope == all ]] && label=All
  if [[ $text ]]; then
    echo "change-prompt($label text> )+disable-search+reload(bash $0 list $scope {q})+refresh-preview"
  else
    echo "change-prompt($label> )+enable-search+reload(bash $0 list $scope)+refresh-preview"
  fi
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

# Only sessions you typed into (cli, IDE, desktop). SDK runs are claude-mem observers, evals and other tools;
# dropping them first spares every later pass a few hundred files
kept=()
while IFS= read -r f; do kept+=("$f"); done < <(
  # awk, not grep -vxF -f: BSD grep takes most of a second over a few hundred fixed patterns
  awk 'FILENAME == ARGV[1] { sdk[$0]; next } !($0 in sdk)' \
    <(search -m1 -o '"entrypoint":"[^"]*"' "${files[@]}" | grep -F '"entrypoint":"sdk' | sed 's/\.jsonl:.*/.jsonl/') \
    <(printf '%s\n' "${files[@]}"))
files=("${kept[@]}")
[[ -e "${files[0]}" ]] || exit 0

if [[ -n "$3" ]]; then
  matched=()
  while IFS= read -r f; do matched+=("$f"); done < <(search -l -F -i -e "$3" "${files[@]}")
  files=("${matched[@]}")
  [[ -e "${files[0]}" ]] || exit 0
fi

cwds=$(search -m1 -o '"cwd":"[^"]*"' "${files[@]}")
# The branch and cwd can change mid-session (a session can enter a worktree), so also take the last of each: perl
# reads each file backwards in 64 KB chunks (overlapping, so a match can't straddle two) until it has both, giving up
# after 2 MB (sessions outside a git repo have no branch). BSD tail takes seconds over this many files
tails=$(perl -e 'for my $f (@ARGV) {
  open(my $h, "<", $f) or next; my $end = -s $h; my ($b, $c);
  for (my $pos = $end; $pos > 0 && $pos > $end - 2097152 && !(defined $b && defined $c); $pos -= 65536) {
    my $from = $pos > 65536 ? $pos - 65536 : 0; my $t;
    seek($h, $from, 0); read($h, $t, ($pos + 512 < $end ? $pos + 512 : $end) - $from);
    my ($lb, $lc); $lb = $1 while $t =~ /"gitBranch":"([^"]*)"/g; $lc = $1 while $t =~ /"cwd":"([^"]*)"/g;
    $b //= $lb; $c //= $lc;
  }
  print "b\t$f\t$b\n" if defined $b; print "C\t$f\t$c\n" if defined $c }' "${files[@]}")

# "<tag>\t<file>\t<value>" lines: m = modified time, c / C = first / last working directory, b = last git branch,
# t = title, p = user prompt;
# keyed by something else: W = "<cwd>\t<worktree>", o = "<session id>\t<worktree it locked>"
{
  if stat -c %Y / >/dev/null 2>&1; then
    stat -c $'m\t%n\t%Y' "${files[@]}"
  else
    stat -f $'m\t%N\t%m' "${files[@]}"
  fi
  sed 's/\.jsonl:/.jsonl\t/; s/^/c\t/' <<< "$cwds"
  # Worktrees as the statusline shows them, read from the filesystem rather than one git call per directory:
  # wt:<name> when the cwd is a linked worktree (its .git is a file), wt→<name> for a worktree the session locked
  # with "session:<id>" (the git-worktrees Module) and still exists
  commons=
  while IFS= read -r d; do
    top=$d; while [[ -n "$top" && ! -e "$top/.git" ]]; do top=${top%/*}; done
    [[ -n "$top" ]] || continue
    common=$top/.git
    if [[ -f "$top/.git" ]]; then
      printf 'W\t%s\t%s\n' "$d" "${top##*/}"
      read -r _ admin < "$top/.git"; [[ "$admin" == /* ]] || admin=$top/$admin
      common=${admin%/worktrees/*}
    fi
    [[ $'\n'"$commons" == *$'\n'"$common"$'\n'* ]] || commons+=$common$'\n'
  done < <({ sed 's/.*"cwd":"//; s/"$//' <<< "$cwds"; sed -n $'s/^C\t[^\t]*\t//p' <<< "$tails"; } | awk '!seen[$0]++')
  while IFS= read -r common; do
    for lock in "$common"/worktrees/*/locked; do
      [[ -f "$lock" ]] || continue
      read -r line < "$lock"; [[ "$line" =~ session:([0-9a-f-]+) ]] || continue
      read -r wt < "${lock%/locked}/gitdir"; wt=${wt%/.git}
      [[ -d "$wt" ]] && printf 'o\t%s\t%s\n' "${BASH_REMATCH[1]}" "${wt##*/}"
    done
  done <<< "$commons"
  printf '%s\n' "$tails"
  search -F -e '"type":"custom-title"' -e '"type":"ai-title"' "${files[@]}" | sed 's/\.jsonl:/.jsonl\t/; s/^/t\t/'
  # Untitled sessions fall back to their first prompt
  search -m5 -F '"role":"user","content":"' "${files[@]}" | sed 's/\.jsonl:/.jsonl\t/; s/^/p\t/'
} | jq -Rrn --arg scope "$2" --arg home "$HOME" '
  def pad($n): . + (" " * ([$n - length, 0] | max));
  reduce (inputs | split("\t")) as [$tag, $f, $v] ({};
    if $tag == "m" then .[$f].time = ($v | tonumber)
    elif $tag == "c" then .[$f].cwd = ("{\($v)}" | fromjson | .cwd)
    elif $tag == "b" then .[$f].branch = $v
    elif $tag == "C" then .[$f].lastcwd = $v
    elif $tag == "W" then .["\u0000wt"][$f] = $v
    elif $tag == "o" then .["\u0000owned"][$f] += [$v]
    elif $tag == "t" then ($v | fromjson) as $j | .[$f] += (if $j.customTitle then {custom: $j.customTitle} else {ai: $j.aiTitle} end)
    elif .[$f].prompt then .
    else ($v | fromjson) as $j | ($j.message.content) as $c
      | if ($j.isMeta | not) and ($c | type) == "string" and $c != "" and ($c | startswith("<") | not)
        then .[$f].prompt = $c else . end
    end)
  | .["\u0000wt"] as $wt | .["\u0000owned"] as $owned | del(.["\u0000wt"], .["\u0000owned"])
  | to_entries | map(.value + {file: .key, title: (.value.custom // .value.ai // .value.prompt)})
  | map(select(.title and .time)) | sort_by(-.time)[]
  | (.title | .[0:300] | gsub("\\s+"; " ") | .[0:100]) as $title
  | (.file | split("/") | last | rtrimstr(".jsonl")) as $id
  # A removed worktree is only recognisable by its path
  | ($wt[.lastcwd // .cwd // ""] // (.lastcwd // .cwd // "" | capture("/\\.claude/worktrees/(?<n>[^/]+)|\\.worktrees/(?<m>[^/]+)") | (.n // .m) + " (removed)") // "") as $in
  | ([($in | select(. != "") | "wt:" + .), ($owned[$id] // [] | .[] | select(. != $in) | "wt→" + .)] | join(" ")
     | if . == "" then "" else "\u001b[31m\(.)\u001b[0m  " end) as $wts
  | (now - .time) as $age
  | [ (if $age < 120 then "\u001b[32m●\u001b[0m " else "  " end)
        + (if $age < 60 then "now" elif $age < 3600 then "\($age / 60 | floor)m ago" elif $age < 86400 then "\($age / 3600 | floor)h ago"
           elif $age < 604800 then "\($age / 86400 | floor)d ago" else .time | localtime | strftime("%Y-%m-%d") end | pad(10)),
      "\u001b[90m\($id[0:8])\u001b[0m",
      "\u001b[35m\(.branch // "" | if length > 24 then .[0:23] + "…" else . end | pad(24))\u001b[0m",
      (if $scope == "all" then "\u001b[34m\(.cwd // "?" | sub("^\($home)"; "~"))\u001b[0m  " else "" end) + $wts + $title,
      $id, .file, .cwd // "" ] | @tsv
'
