#!/bin/bash

alias d="docker"

# Prune environemnt
alias dprune="docker system prune --volumes"
alias dprunevolumes="docker volume prune"

# System
alias dsize="docker system df"
alias dclearContainers="docker rmi $(docker images -f "dangling=true" -q)"
alias dclearVolumes="docker volume rm $(docker volume ls -qf dangling=true)"

# Shortcuts
alias di="d images"
alias dp="d ps"
alias dv="d volume"
alias dn="d network"
alias dt="d tag"
alias dr="d run --rm -it"
alias dtag="tagDockerImage"
alias de="dockerExecuteIteration"

# Tools
alias dip="d inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"

function dockerExecuteIteration() {
  docker exec -it $1 bash
}

function tagDockerImage() {
  CONTAINER="$1"
  REPOSITORY="$2"
  TAG="$3"

  docker tag "$CONTAINER" "$REPOSITORY/$TAG"
}

alias lzd="lazydocker"
