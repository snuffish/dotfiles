#!/bin/bash

function venv() {
  autoload -U compinit
  compinit

  eval "$(_ESPTOOL_COMPLETE=zsh_source esptool)"
  eval "$(_ESPSECURE_COMPLETE=zsh_source espsecure)"
  eval "$(_ESPEFUSE_COMPLETE=zsh_source espefuse)"
}

