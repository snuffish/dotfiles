  alias .="cd ~"
#!/usr/bin/env bash

# ==============================================================================
# 1. Directory & Navigation Shortcuts
# ==============================================================================
alias .d='cd "$HOME/Desktop"'
alias .p='cd "$HOME/Projects"'
alias .config='cd "$HOME/.config"'
alias .piop='cd "$HOME/Documents/PlatformIO/Projects"'
alias .="cd ~"

# Temp directory navigation with automatic fallback
alias .tmp='cd /tmp 2>/dev/null || { mkdir -p "$HOME/.tmp" && cd "$HOME/.tmp"; }'

# Unity projects navigation
if [[ "$ENV_PROFILE" == "Windows" ]]; then
  alias .up='cd /mnt/d/UnityProjects 2>/dev/null || cd /d/UnityProjects 2>/dev/null || cd "$HOME/UnityProjects"'
else
  alias .up='cd "$HOME/UnityProjects"'
fi

# ==============================================================================
# 2. File Opener Utility (o / open)
# ==============================================================================
if [[ "$ENV_PROFILE" == "Linux" ]]; then
  function open() {
    if command -v nautilus >/dev/null 2>&1; then
      nautilus --new-window "${1:-.}" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "${1:-.}" >/dev/null 2>&1 &
    else
      echo "Error: Neither nautilus nor xdg-open is available." >&2
      return 1
    fi
  }
elif [[ "$ENV_PROFILE" == "Windows" ]]; then
  if ! command -v open >/dev/null 2>&1; then
    alias open="explorer.exe"
  fi
fi

alias o="open"

# ==============================================================================
# 3. System Power & Session Management
# ==============================================================================
reboot() {
  if [[ "$ENV_PROFILE" == "Mac" ]]; then
    defaults write com.apple.loginwindow TALLogoutSavesState -bool false && \
    defaults -currentHost write com.apple.loginwindow TALLogoutSavesState -bool false && \
    defaults -currentHost delete com.apple.loginwindow TALAppsToRelaunchAtLogin 2>/dev/null
    osascript -e 'tell app "System Events" to restart with state saving preference'
  elif [[ "$ENV_PROFILE" == "Windows" ]]; then
    sudo psshutdown -rf -t 0
  else
    sudo reboot now
  fi
}

# ==============================================================================
# 4. Platform & Environment-Specific Shortcuts
# ==============================================================================
if [[ "$ENV_PROFILE" == "Windows" ]]; then
  # Drive navigation (supports WSL /mnt/ and MSYS / Git Bash paths)
  alias C='cd /c/ 2>/dev/null || cd /mnt/c/'
  alias 'C:'=C
  alias D='cd /mnt/d/ 2>/dev/null || cd /d/'
  alias 'D:'=D

  alias findport="tcpview"
fi
