#!/bin/bash

autoload -U compinit
compinit

function venv() {
  python -m venv venv
  source venv/bin/activate

  eval "$(_ESPTOOL_COMPLETE=zsh_source esptool)"
  eval "$(_ESPSECURE_COMPLETE=zsh_source espsecure)"
  eval "$(_ESPEFUSE_COMPLETE=zsh_source espefuse)"
}
