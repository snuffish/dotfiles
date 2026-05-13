#!/usr/bin/env bash

# This script provides utility functions to interactively select and run commands
# defined in a JSON configuration file using fzf.

# Interactive command runner using fzf and a JSON config.
#
# Arguments:
#   -t, --title TEXT    Optional title/header for the fzf selection window.
#   KEY                 The top-level key in the JSON file to fetch commands from.
#
# Usage:
#   run_fzf_json [-t "My Menu"] "scripts"
#
# Dependencies:
#   - jq: For parsing JSON.
#   - fzf: For the interactive fuzzy finder.
#
# Configuration:
#   Expects a 'commands.json' file in the same directory as this script
#   (/home/snuffish/.terminal/utils/commands.json).
#   The JSON should follow this structure:
#   {
#     "key_name": {
#       "Command Description": "bash command to execute",
#       "Another Description": "echo 'hello world'"
#     }
#   }

run_fzf_json() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local config_file=""
  local title=""
  local key=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -t | --title)
      title="$2"
      shift 2
      ;;
    *.json)
      config_file="$1"
      shift
      ;;
    *)
      key="$1"
      shift
      ;;
    esac
  done

  # Fallback to default file in script directory if no path provided
  config_file="${config_file:-$script_dir/commands.json}"

  # Validation
  if [[ ! -f "$config_file" ]]; then
    echo "Error: JSON file not found at $config_file"
    return 1
  fi

  if [[ -z "$key" ]]; then
    echo "Usage: run_fzf_json [file.json] <key> [--title 'Custom Title']"
    return 1
  fi

  # Check if the key exists in the JSON
  if ! jq -e ".[\"$key\"]" "$config_file" >/dev/null 2>&1; then
    echo "Error: Key '$key' not found in $config_file"
    return 1
  fi

  # Set header: use provided title or fallback to the key name
  local fzf_header="${title:-Select command ($key):}"

  # Extract keys in original order using keys_unsorted
  local choice_name=$(jq -j ".[\"$key\"] | keys_unsorted[] + \"\\u0000\"" "$config_file" |
    fzf --read0 --height 40% --reverse --header "$fzf_header")

  # Execute the command if a choice was made
  if [[ -n "$choice_name" ]]; then
    local cmd=$(jq -r ".[\"$key\"][\"$choice_name\"]" "$config_file")
    echo "Executing: $cmd"
    eval "$cmd"
  fi
}
