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

  # Hantera flaggor och argument
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

  # Om ingen fil angavs, använd standardfilen i skriptets mapp
  config_file="${config_file:-$script_dir/commands.json}"

  # Valideringar
  if [[ ! -f "$config_file" ]]; then
    echo "Fel: Hittade inte JSON-filen: $config_file"
    return 1
  fi

  if [[ -z "$key" ]]; then
    echo "Fel: Ange en nyckel (t.ex. 'dev' eller 'git')."
    return 1
  fi

  # Kontrollera om nyckeln faktiskt finns i filen
  if ! jq -e ".[\"$key\"]" "$config_file" >/dev/null 2>&1; then
    echo "Fel: Nyckeln '$key' hittades inte i $config_file"
    return 1
  fi

  local fzf_header="${title:-Run ($key):}"

  # Hämta namn i originalordning
  local choice_name=$(jq -j ".[\"$key\"] | keys_unsorted[] + \"\\u0000\"" "$config_file" |
    fzf --read0 --height 40% --reverse --header "$fzf_header")

  if [[ -n "$choice_name" ]]; then
    local cmd=$(jq -r ".[\"$key\"][\"$choice_name\"]" "$config_file")
    echo "Run: $cmd"
    eval "$cmd"
  fi
}
