#!/usr/bin/env bash

function CHECK_CONNECTED_DEVICE() {
  echo "Now CONNECT/UNPLUG the device and press Enter to continue..."
  read DUMMY_VAR
  DEVICES_PLUGGED_IN=$(\ls -d /dev/*)

  echo "Now UNPLUG/CONNECT the device and press Enter to continue..."
  read DUMMY_VAR
  DEVICES_DISCONNECTED=$(\ls -d /dev/*)

  TEMP_FILE1=$(mktemp)
  TEMP_FILE2=$(mktemp)

  echo "$DEVICES_PLUGGED_IN" > "$TEMP_FILE1"
  echo "$DEVICES_DISCONNECTED" > "$TEMP_FILE2"

  echo "Differences (devices that were removed or added):"
  diff "$TEMP_FILE1" "$TEMP_FILE2"

  # Clean up
  rm "$TEMP_FILE1" "$TEMP_FILE2"
}

alias devcheck=CHECK_CONNECTED_DEVICE
