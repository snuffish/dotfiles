#!/bin/bash

export USERNAME=$(whoami)
export PATH="$PATH:/usr/libexec/"
export TLDR_AUTO_UPDATE_DISABLED=true

unset SHELL_ENV
[[ -n "$ZSH_VERSION" ]] && export SHELL_ENV="ZSH"
[[ -n "$BASH_VERSION" ]] && export SHELL_ENV="BASH"
