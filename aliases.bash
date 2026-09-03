#!/bin/bash

if [[ $ENV_PROFILE == "Mac" || $ENV_PROFILE = "Linux" ]]; then
  # Mac
  export DEVICE="MAC"
  alias o="open"
  alias .="cd ~"
  alias .tmp="cd /tmp"
  alias .up='cd $HOME/UnityProjects'
  if [[ $ENV_PROFILE == "Mac" ]]; then
    alias reboot="defaults write com.apple.loginwindow TALLogoutSavesState -bool false && defaults -currentHost write com.apple.loginwindow TALLogoutSavesState -bool false && defaults -currentHost delete com.apple.loginwindow TALAppsToRelaunchAtLogin 2>/dev/null; osascript -e 'tell app \"System Events\" to restart with state saving preference'"
  else
    alias reboot="sudo reboot now"
  fi
elif [[ $ENV_PROFILE = "Windows" ]]; then
  # Home PC (Windows)
  export DEVICE="HOME"
  alias C='cd /c/'
  alias 'C:'=C
  alias D='cd /mnt/d/'
  alias 'D:'=D
  alias .up="D: && cd UnityProjects"
  alias .tmp='cd $HOME/.tmp'
  alias reboot="sudo psshutdown -rf -t 0"
  alias findport="tcpview"
fi

if [[ $ENV_PROFILE == "Linux" ]]; then
  function open() {
    if command -v nautilus >/dev/null 2>&1; then
      nautilus --new-window "${1:-.}"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "${1:-.}"
    else
      echo "Error: Neither nautilus nor xdg-open is available."
      return 1
    fi
  }

  alias o="open"
elif [[ $ENV_PROFILE == 'darwin'* ]]; then
  alias o="open"
fi

alias .d='cd $HOME/Desktop'
alias .p='cd $HOME/Projects'
alias .config='cd $HOME/.config'
alias .piop='cd $HOME/Documents/PlatformIO/Projects'
