#!/bin/bash

export FZF_COMPLETION_OPTS='--border --info=inline'
export FZF_COMPLETION_TRIGGER='``'

# Use fd for fzf path and directory completion if available
_fzf_compgen_path() {
  if command -v fd >/dev/null 2>&1; then
    fd --hidden --exclude .git . "$1"
  else
    command find "$1" -path '*/.*' -prune -o -type f -print -o -type l -print 2>/dev/null | sed 's@^\./@@'
  fi
}

_fzf_compgen_dir() {
  if command -v fd >/dev/null 2>&1; then
    fd --type d --hidden --exclude .git . "$1"
  else
    command find "$1" -path '*/.*' -prune -o -type d -print 2>/dev/null | sed 's@^\./@@'
  fi
}

# Preview files using bat during fzf completion
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza -T --color=always --level=2 {} 2>/dev/null || tree -C -L 2 {} 2>/dev/null' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'" "$@" ;;
    *)            fzf --preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || cat {} 2>/dev/null' "$@" ;;
  esac
}

# Zsh completion widget to enable direct Tab completion on find / ff without requiring trigger
_fzf_setup_completion_widget() {
  if [[ -n "$ZSH_VERSION" ]]; then
    _find_fzf_completion_widget() {
      local tokens=(${(z)LBUFFER})

      if [[ "${tokens[1]}" == "find" || "${tokens[1]}" == "ff" ]]; then
        # If completing the command name itself (e.g. 'find' without trailing space)
        if [[ ${#tokens} -eq 1 && ! "$LBUFFER" =~ [[:space:]]+$ ]]; then
          zle ${fzf_default_completion:-expand-or-complete}
          return
        fi

        # Check for flags (-*)
        local has_flag=0
        for t in "${tokens[@]:1}"; do
          if [[ "$t" == -* ]]; then
            has_flag=1
            break
          fi
        done

        if [[ $has_flag -eq 0 ]]; then
          local prefix=""
          if [[ "$LBUFFER" =~ [[:space:]]+$ ]]; then
            prefix=""
          else
            prefix="${tokens[-1]}"
          fi
          local lbuf="${LBUFFER%$prefix}"
          local cmd_word="${tokens[1]}"
          _fzf_path_completion "$prefix" "$lbuf"
          zle reset-prompt
          return
        fi
      fi

      # Fallback to standard fzf completion widget
      zle fzf-completion
    }
    zle -N _find_fzf_completion_widget
    bindkey '^I' _find_fzf_completion_widget
  fi
}

# Bash completion function for find / ff
_fzf_setup_completion_bash() {
  if [[ -n "$BASH_VERSION" ]]; then
    _fzf_find_complete_bash() {
      local cur="${COMP_WORDS[COMP_CWORD]}"
      if [[ "$cur" == -* ]]; then
        return 0
      fi
      local search_dir="${cur:-.}"
      search_dir="${search_dir/#\~/$HOME}"
      [[ ! -d "$search_dir" ]] && search_dir=$(dirname "$search_dir" 2>/dev/null || echo ".")

      local selected
      if command -v fd >/dev/null 2>&1; then
        selected=$(fd --hidden --exclude .git . "$search_dir" 2>/dev/null | fzf --height 40% --reverse)
      else
        selected=$(command find "$search_dir" -not -path '*/.*' 2>/dev/null | fzf --height 40% --reverse)
      fi

      if [[ -n "$selected" ]]; then
        COMPREPLY=( "$selected" )
      fi
    }
    complete -o default -o nospace -F _fzf_find_complete_bash find ff
  fi
}
