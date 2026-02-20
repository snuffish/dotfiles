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

  # shellcheck source=/dev/null
  source "$FILE"
  filename=$(getFileName "$FILE")
  printf "Loaded => %s\n" "$filename"
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
