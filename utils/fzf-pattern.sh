#!/usr/bin/env bash
# Pattern mode for fzf pickers (gb, cr/agr/ar: Ctrl-R toggles; gw: Ctrl-F, its Ctrl-R prunes): fzf only displays,
# this script matches.
# The prompt holds the state ("... pattern> "); the picker exports FZFP_DIR, a temp dir whose "rows" file holds
# its full list.
#   fzf-pattern.sh filter NTH QUERY  rows on stdin whose tab-separated fields NTH (e.g. 2,3) match QUERY as a
#                                    regex, or as a whole-field glob (*.py) when QUERY isn't a valid regex;
#                                    lowercase QUERY ignores case (like fzf); colors and padding are ignored
#   fzf-pattern.sh pipe NTH          stdin -> the cache, then filtered by $FZF_QUERY in pattern mode, else as is;
#                                    every reload goes through it so the cache stays current. The cache is replaced
#                                    only when the list finishes: fzf kills a reload when the next one starts
#   fzf-pattern.sh change NTH        fzf action for a query change: re-filter the cache in pattern mode, else none
#   fzf-pattern.sh toggle NTH        fzf action for Ctrl-R: add/remove "pattern" in the prompt and reload the cache
#                                    (for pickers whose own keys don't rebuild the prompt)

self="${BASH_SOURCE[0]}"
nth="$2"
cache="$FZFP_DIR/rows"

filter() {
  local q="$1" re icase=
  [[ -n "$q" ]] || { cat; return; }
  grep -Eq -- "$q" </dev/null 2>/dev/null
  if [[ $? -eq 2 ]]; then
    # Not a valid regex: a glob over the whole field
    re="^$(printf '%s' "$q" | sed -e 's/[.+(){}|^$\\]/\\&/g' -e 's/\*/.*/g' -e 's/?/./g')\$"
  else
    re="$q"
  fi
  [[ "$q" == *[[:upper:]]* ]] || icase=1
  RE="$re" NTH="$nth" ICASE="$icase" awk -F '\t' '
    BEGIN { re = ENVIRON["RE"]; n = split(ENVIRON["NTH"], f, ","); ic = ENVIRON["ICASE"] != ""; if (ic) re = tolower(re) }
    {
      for (i = 1; i <= n; i++) {
        s = $(f[i]); gsub(/\033\[[0-9;]*m/, "", s); gsub(/^ +| +$/, "", s)
        if (ic) s = tolower(s)
        if (s ~ re) { print; next }
      }
    }' 2>/dev/null
  return 0
}

case "$1" in
  filter) filter "$3" ;;
  pipe)
    if [[ -n "$FZFP_DIR" ]]; then tee "$cache.$$"; else cat; fi \
      | if [[ "$FZF_PROMPT" == *pattern* ]]; then filter "$FZF_QUERY"; else cat; fi
    [[ -n "$FZFP_DIR" ]] && mv -f "$cache.$$" "$cache" ;;
  change)
    [[ "$FZF_PROMPT" == *pattern* ]] && echo "reload(bash $self filter $nth {q} < \"\$FZFP_DIR/rows\")"
    exit 0 ;;
  toggle)
    base="${FZF_PROMPT%> }"
    if [[ "$base" == *pattern ]]; then
      base="${base%pattern}"; base="${base% }"
      echo "change-prompt(${base:+$base}> )+enable-search+reload(cat \"\$FZFP_DIR/rows\")"
    else
      echo "change-prompt(${base:+$base }pattern> )+disable-search+reload(bash $self filter $nth {q} < \"\$FZFP_DIR/rows\")"
    fi ;;
  *) echo "usage: fzf-pattern.sh filter NTH QUERY | pipe NTH | change NTH | toggle NTH" >&2; exit 2 ;;
esac
