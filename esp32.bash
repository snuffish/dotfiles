#!/bin/bash

if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U compinit
  compinit
fi

function venv() {
  python -m venv venv
  source venv/bin/activate

  local shell_type="${SHELL_ENV:-BASH}"
  if [[ "$shell_type" == "ZSH" || -n "$ZSH_VERSION" ]]; then
    eval "$(_ESPTOOL_COMPLETE=zsh_source esptool)"
    eval "$(_ESPSECURE_COMPLETE=zsh_source espsecure)"
    eval "$(_ESPEFUSE_COMPLETE=zsh_source espefuse)"
  else
    eval "$(_ESPTOOL_COMPLETE=bash_source esptool)"
    eval "$(_ESPSECURE_COMPLETE=bash_source espsecure)"
    eval "$(_ESPEFUSE_COMPLETE=bash_source espefuse)"
  fi
}
