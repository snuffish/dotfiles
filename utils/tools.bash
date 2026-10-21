#!/bin/bash

# Args: (filepath)
function getFileName() {
  FILEPATH=$1
  printf "%s\n" "${FILEPATH##*/}"
}

# Args: (string,match)
function stringContains() {
  STR=$1
  MATCH=$2
  if [[ "$STR" == *"$MATCH"* ]]; then
    echo 1
  else
    echo 0
  fi
}

# Args: (path)
function convertPathToWin32() {
  converted=$(echo "$1" | sed 's/^\///' | sed 's/\//\\/g' | sed 's/^./\0:/')
  echo "$converted"
}

function loadSource() {
  FILE=$1

  if [[ ! -f "$FILE" ]]; then
    printf "\e[31m✗ Missing required file: %s\e[0m\n" "$FILE" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$FILE"
  return 0
}

function aliasExists() {
  ALIAS_NAME=$1
  if alias "$ALIAS_NAME" >/dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}

alias snip="snippingtool"
