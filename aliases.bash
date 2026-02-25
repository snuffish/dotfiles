#!/bin/bash

if [[ $ENV_PROFILE == "Mac" || $ENV_PROFILE = "Linux" ]]; then
  # Mac
  export DEVICE="MAC"
  alias o="open"
  alias .tmp="cd /tmp"
  alias .up='cd $HOME/UnityProjects'
  alias reboot="sudo reboot now"
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
    /usr/bin/nautilus --new-window "$1"
  }

  alias o="open"
elif [[ $ENV_PROFILE == 'darwin'* ]]; then
  alias o="open"
fi

alias .d='cd $HOME/Desktop'
alias .p='cd $HOME/Projects'
alias .config='$HOME/.config'
alias .piop='$HOME/Documents/PlatformIO/Projects'
