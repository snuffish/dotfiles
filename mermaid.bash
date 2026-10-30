#!/bin/bash

# Renders Mermaid diagrams inline: kitty graphics in Ghostty (also through tmux), block symbols elsewhere.
# Usage: mmd [file.mmd | file.md]   reads stdin without a file; a .md renders each ```mermaid block in order.
# MMD_FORMAT=kitty|sixels|iterm|symbols overrides the detected output format.
function mmd() {
  local src=${1:-/dev/stdin} dir format block png

  if ! command -v mmdc >/dev/null 2>&1; then
    echo "mmd: mmdc not found (PUPPETEER_SKIP_DOWNLOAD=1 npm i -g @mermaid-js/mermaid-cli)" >&2
    return 1
  fi

  dir=$(mktemp -d) || return 1

  if [[ $src == *.md ]]; then
    awk -v dir="$dir" '
      /^```mermaid/ { n++; file = sprintf("%s/%02d.mmd", dir, n); inside = 1; next }
      inside && /^```/ { inside = 0; next }
      inside { print > file }
    ' "$src"
  else
    cat "$src" >"$dir/01.mmd"
  fi

  format=${MMD_FORMAT:-symbols}
  if [[ -z $MMD_FORMAT ]]; then
    if [[ $TERM_PROGRAM == ghostty ]] ||
      { [[ -n $TMUX ]] && [[ $(tmux show-environment -g TERM_PROGRAM 2>/dev/null) == "TERM_PROGRAM=ghostty" ]]; }; then
      format=kitty
    fi
  fi

  # find instead of a glob: zsh aborts on a glob with no match
  find "$dir" -name '*.mmd' | sort | while read -r block; do
    png=${block%.mmd}.png
    # Use the installed Chrome instead of the Chromium bundle that puppeteer would download
    PUPPETEER_EXECUTABLE_PATH=${PUPPETEER_EXECUTABLE_PATH:-/usr/bin/google-chrome-stable} \
      mmdc -q -i "$block" -o "$png" -t dark -b transparent -s 2 || continue
    chafa -f "$format" "$png"
  done

  if [[ -z $(find "$dir" -name '*.mmd') ]]; then
    echo "mmd: no mermaid diagram in $src" >&2
  fi
  rm -rf "$dir"
}
