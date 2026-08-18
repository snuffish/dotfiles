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
#   Defaults to searching for 'commands.json' in:
#   1. Script directory ($script_dir/commands.json)
#   2. Terminal config root ($script_dir/../commands.json)
#   3. Home terminal directory (~/.terminal/commands.json)
#
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
      if [[ -n "$2" && "$2" != -* ]]; then
        title="$2"
        shift 2
      else
        echo "Error: Option $1 requires a non-empty argument."
        return 1
      fi
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

  # Expand tilde in config_file if present
  config_file="${config_file/#\~/$HOME}"

  # Fallback: search standard config locations if path not specified
  if [[ -z "$config_file" ]]; then
    if [[ -f "$script_dir/commands.json" ]]; then
      config_file="$script_dir/commands.json"
    elif [[ -f "$script_dir/../commands.json" ]]; then
      config_file="$script_dir/../commands.json"
    elif [[ -f "$HOME/.terminal/commands.json" ]]; then
      config_file="$HOME/.terminal/commands.json"
    fi
  fi

  # Validation
  if [[ ! -f "$config_file" ]]; then
    echo "Error: JSON file not found at $config_file"
    return 1
  fi

  if [[ -z "$key" ]]; then
    echo "Usage: run_fzf_json [file.json] <key> [--title 'Custom Title']"
    return 1
  fi

  # Check if the key exists in the JSON safely using --arg
  if ! jq -e --arg k "$key" '.[$k] != null' "$config_file" >/dev/null 2>&1; then
    echo "Error: Key '$key' not found in $config_file"
    return 1
  fi

  # Set header: use provided title or fallback to the key name
  local fzf_header="${title:-Select command ($key):}"

  # Extract keys in original order using keys_unsorted
  local choice_name
  choice_name=$(jq -j --arg k "$key" '.[$k] | keys_unsorted[] + "\u0000"' "$config_file" |
    fzf --read0 --height 40% --reverse --header "$fzf_header" \
      --preview "jq -r --arg k \"$key\" --arg c {} '.[\$k][\$c]' \"$config_file\"" \
      --preview-window "down:3:wrap" \
      --preview-label " Command " \
      --preview-label-pos "2" \
      --color "preview-border:gray")

  # Execute the command if a choice was made
  if [[ -n "$choice_name" ]]; then
    local cmd
    cmd=$(jq -r --arg k "$key" --arg c "$choice_name" '.[$k][$c]' "$config_file")
    echo "Executing: $cmd"
    eval "$cmd"
  fi
}
