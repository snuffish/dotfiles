#!/bin/bash


if [[ $OS == "Mac" && $USERNAME == "snuffish" ]]; then
  # Mac
  export DEVICE="MAC"
  alias {open,o}="open"
  alias .p="cd $HOME/Projects"
  alias .d="cd $HOME/Desktop"
  alias .tmp="cd /tmp"
  alias .up="cd $HOME/UnityProjects"
else
  OS="$(lsb_release -is)"

  # Home PC (Windows)
  export DEVICE="HOME"
  alias {C,C:}="cd /c/"
  alias {D,D:}="cd /mnt/d/"
  alias .up="D: && cd UnityProjects"
  alias .p="cd $HOME/Projects"
  alias {.v,.vgr}="D: && cd VGR"
  if [[ $OS == "ManjaroLinux" ]]; then
    alias {open,o}="nautilus"
  else
    alias {open,o}="explorer.exe"
  fi
  alias .tmp="cd $HOME/.tmp"
  alias .d="cd $HOME/OneDrive/Desktop"
  alias reboot="sudo psshutdown -rf -t 0"
  alias findport="tcpview"

  nvm use v20.11.0
fi

alias .config="$HOME/.config"
