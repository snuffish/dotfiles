#!/bin/bash

alias az_beijer-login="az login --tenant $BEIJER_TENANT_ID"


# Pick from your Azure DevOps PRs with fzf: Enter opens one, Ctrl-Y copies its URL (--all adds completed and abandoned)
alias adopr="bash $HOME/.terminal/utils/adopr.sh"
