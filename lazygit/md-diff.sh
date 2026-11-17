#!/bin/sh
# lazygit extDiff renderer: render markdown with glow, plain colored diff for everything else.
# git passes: path old-file old-hex old-mode new-file new-hex new-mode
path=$1
old=$2
new=$5
# Untracked files come from `git diff --no-index /dev/null <file>`, where git passes /dev/null as the path.
[ "$path" = /dev/null ] && path=$new

case "$path" in
  *.md | *.markdown)
    # Deleted files have no new side to render; they fall through to the plain diff.
    if [ "$new" != /dev/null ]; then
      # glow 3 always reads its own glow.yml (tui: true there), even with --config.
      # lazygit 0.64 passes no width; the diff panel is about 2/3 of the tmux pane (sidePanelWidth 0.3333).
      cols=$(tmux display-message -p '#{pane_width}' 2>/dev/null || echo 150)
      HOME="${TMPDIR:-/tmp}/lazygit-glow" exec glow --style dark --width $((cols * 2 / 3 - 6)) "$new"
    fi
    ;;
esac

git diff --no-index --no-ext-diff --color=always -- "$old" "$new" |
  sed -e "s#a/${old#/}#a/$path#g" -e "s#b/${new#/}#b/$path#g"
exit 0
