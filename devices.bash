#!/usr/bin/env bash

function detect_device_changes() {
  # Create temporary files for comparison
  local temp_file_before
  local temp_file_after
  temp_file_before=$(mktemp)
  temp_file_after=$(mktemp)

  # Cleanup temp-files on exit or error
  trap 'rm -f "$temp_file_before" "$temp_file_after"' EXIT

  # First state
  echo "Step 1: Prepare the initial state of your device."
  echo "Press Enter when ready..."
  read -r _

  local devices_before
  devices_before=$(\ls -d /dev/*)

  # Second state
  echo "Step 2: Now CONNECT or DISCONNECT your device."
  echo "Press Enter when done..."
  read -r _

  local devices_after
  devices_after=$(\ls -d /dev/*)

  # Save device lists to files
  echo "$devices_before" > "$temp_file_before"
  echo "$devices_after" > "$temp_file_after"
  
  # Display results
  echo "Results - Devices that were added or removed:"
  diff "$temp_file_before" "$temp_file_after"
}

# Create a user-friendly alias
alias devcheck=detect_device_changes
