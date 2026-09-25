#!/usr/bin/env bash

# ==============================================================================
# diskspace.bash — Intelligent Disk Space Inspector & Interactive Cleaner
# Supports macOS (APFS aware), Linux, and Windows (WSL/Git Bash).
# Compatible with both Bash and Zsh.
# ==============================================================================

# Unset any stale alias if previously defined
unalias diskspace 2>/dev/null || true

# ------------------------------------------------------------------------------
# Color & Formatting Utilities
# ------------------------------------------------------------------------------
_ds_setup_colors() {
  if [[ -t 1 ]]; then
    DS_BOLD=$'\033[1m'
    DS_DIM=$'\033[2m'
    DS_RESET=$'\033[0m'
    DS_RED=$'\033[31m'
    DS_GREEN=$'\033[32m'
    DS_YELLOW=$'\033[33m'
    DS_BLUE=$'\033[34m'
    DS_CYAN=$'\033[36m'
  else
    DS_BOLD=""
    DS_DIM=""
    DS_RESET=""
    DS_RED=""
    DS_GREEN=""
    DS_YELLOW=""
    DS_BLUE=""
    DS_CYAN=""
  fi
}

# ------------------------------------------------------------------------------
# Helper: Measure Directory Size in Human Readable Format
# ------------------------------------------------------------------------------
_ds_get_dir_size() {
  local target="$1"
  if [[ -d "$target" ]]; then
    local sz
    sz=$(du -sh "$target" 2>/dev/null | awk '{print $1}')
    if [[ -n "$sz" ]]; then
      echo "$sz"
      return 0
    fi
  fi
  echo "0B"
}

# ------------------------------------------------------------------------------
# Subcommand: status (Default) — Accurate Mounts & Visual Capacity Bar
# ------------------------------------------------------------------------------
_diskspace_status() {
  _ds_setup_colors

  printf "%s%s=== Disk Space Overview ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"

  local os_type="${ENV_PROFILE:-}"
  if [[ -z "$os_type" ]]; then
    case "$(uname -s)" in
      Darwin) os_type="Mac" ;;
      Linux)  os_type="Linux" ;;
      *)      os_type="Other" ;;
    esac
  fi

  if [[ "$os_type" == "Mac" ]]; then
    # APFS-aware parsing: Filter out synthetic APFS volumes, prioritize /System/Volumes/Data
    df -h | awk -v bold="$DS_BOLD" -v reset="$DS_RESET" \
                -v red="$DS_RED" -v yellow="$DS_YELLOW" -v green="$DS_GREEN" '
    BEGIN {
      printf "%-28s %-7s %-7s %-7s %-6s   %-14s   %s\n", "MOUNT", "SIZE", "USED", "AVAIL", "CAP", "USAGE", "STATUS"
      print "--------------------------------------------------------------------------------"
    }
    NR > 1 && $1 ~ /^\/dev\// && $9 !~ /\/System\/Volumes\/(VM|Preboot|Update|xarts|iSCPreboot|Hardware)/ {
      cap_str = $5
      sub(/%/, "", cap_str)
      cap_num = cap_str + 0

      filled = int(cap_num / 10)
      bar = ""
      for (i = 1; i <= 10; i++) {
        if (i <= filled) bar = bar "■"
        else bar = bar "·"
      }

      mount = $9
      if (mount == "/System/Volumes/Data") {
        mount = "/System/Volumes/Data (User)"
      } else if (mount == "/") {
        mount = "/ (System)"
      }

      if (cap_num >= 90) {
        c_start = red bold
        c_end = reset
        status_tag = red bold "🚨 CRITICAL" reset
      } else if (cap_num >= 75) {
        c_start = yellow bold
        c_end = reset
        status_tag = yellow bold "⚠️  LOW" reset
      } else {
        c_start = green
        c_end = reset
        status_tag = green "🟢 OK" reset
      }

      printf "%-28s %-7s %-7s %-7s %s%-6s%s   %s[%s]%s   %s\n", mount, $2, $3, $4, c_start, $5, c_end, c_start, bar, c_end, status_tag
    }'
  else
    # Linux / Other platforms
    df -h -x squashfs -x tmpfs -x devtmpfs -x overlay -x shm 2>/dev/null | awk -v bold="$DS_BOLD" -v reset="$DS_RESET" \
                -v red="$DS_RED" -v yellow="$DS_YELLOW" -v green="$DS_GREEN" '
    BEGIN {
      printf "%-28s %-7s %-7s %-7s %-6s   %-14s   %s\n", "MOUNT", "SIZE", "USED", "AVAIL", "CAP", "USAGE", "STATUS"
      print "--------------------------------------------------------------------------------"
    }
    NR > 1 {
      cap_str = $5
      sub(/%/, "", cap_str)
      cap_num = cap_str + 0

      filled = int(cap_num / 10)
      bar = ""
      for (i = 1; i <= 10; i++) {
        if (i <= filled) bar = bar "■"
        else bar = bar "·"
      }

      mount = $6 ? $6 : $9

      if (cap_num >= 90) {
        c_start = red bold
        c_end = reset
        status_tag = red bold "🚨 CRITICAL" reset
      } else if (cap_num >= 75) {
        c_start = yellow bold
        c_end = reset
        status_tag = yellow bold "⚠️  LOW" reset
      } else {
        c_start = green
        c_end = reset
        status_tag = green "🟢 OK" reset
      }

      printf "%-28s %-7s %-7s %-7s %s%-6s%s   %s[%s]%s   %s\n", mount, $2, $3, $4, c_start, $5, c_end, c_start, bar, c_end, status_tag
    }'
  fi

  # Determine if user data volume is under pressure
  local data_cap
  if [[ "$os_type" == "Mac" ]]; then
    data_cap=$(df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {sub(/%/,"",$5); print $5}')
  else
    data_cap=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {sub(/%/,"",$5); print $5}')
  fi

  data_cap=${data_cap:-0}

  printf "\n"
  if [[ $data_cap -ge 90 ]]; then
    printf "%s%s🚨 WARNING: Disk is critically full (%s%% capacity)!%s\n" "$DS_BOLD" "$DS_RED" "$data_cap" "$DS_RESET"
    printf "   • Run %sdiskspace clean%s to free up caches & unused Docker containers/images\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace clean --dry-run%s to preview reclaimable space\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace top%s to locate large folders in %s\n\n" "$DS_BOLD" "$DS_RESET" "$HOME"
  elif [[ $data_cap -ge 75 ]]; then
    printf "%s%s⚠️  NOTICE: Disk space is getting low (%s%% capacity).%s\n" "$DS_BOLD" "$DS_YELLOW" "$data_cap" "$DS_RESET"
    printf "   • Run %sdiskspace clean%s to interactively reclaim space\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace top%s to find large folders\n\n" "$DS_BOLD" "$DS_RESET"
  else
    printf "%s💡 Tip:%s Use %sdiskspace clean%s to clean caches or %sdiskspace top%s to scan large folders.\n\n" \
      "$DS_DIM" "$DS_RESET" "$DS_BOLD" "$DS_RESET" "$DS_BOLD" "$DS_RESET"
  fi
}

# ------------------------------------------------------------------------------
# Subcommand: top — Scan Largest Directories
# ------------------------------------------------------------------------------
_diskspace_top() {
  _ds_setup_colors
  local target_dir="${1:-$HOME}"
  local count="${2:-10}"

  # Expand tilde if present
  target_dir="${target_dir/#\~/$HOME}"

  if [[ ! -d "$target_dir" ]]; then
    echo "Error: Directory '$target_dir' does not exist." >&2
    return 1
  fi

  printf "%s%sScanning top %s largest directories in: %s%s%s\n\n" \
    "$DS_BOLD" "$DS_CYAN" "$count" "$DS_RESET$DS_BOLD" "$target_dir" "$DS_RESET"

  printf "%-10s %s\n" "SIZE" "DIRECTORY"
  printf "%s\n" "--------------------------------------------------------"

  # du -d 1 -h is compatible with both macOS (BSD) and Linux (GNU)
  du -d 1 -h "$target_dir" 2>/dev/null | sort -hr | head -n "$((count + 1))" | while read -r sz dir; do
    if [[ "$dir" == "$target_dir" ]]; then
      printf "%s%-10s %s (Total)%s\n" "$DS_BOLD$DS_BLUE" "$sz" "$dir" "$DS_RESET"
    else
      printf "%-10s %s\n" "$sz" "$dir"
    fi
  done
  printf "\n"
}

# ------------------------------------------------------------------------------
# Subcommand: clean — Interactive & Modular Disk Cleanup Engine
# ------------------------------------------------------------------------------
_diskspace_clean() {
  _ds_setup_colors

  local mode="interactive"
  local dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        mode="dry_run"
        shift
        ;;
      --all)
        mode="all"
        shift
        ;;
      --docker)
        mode="docker"
        shift
        ;;
      --pkg)
        mode="pkg"
        shift
        ;;
      --help|-h)
        printf "%sUsage: diskspace clean [options]%s\n\n" "$DS_BOLD" "$DS_RESET"
        echo "Options:"
        echo "  (none)      Interactive multi-selection menu (fzf if available, else menu)"
        echo "  --dry-run   Preview all reclaimable space without deleting anything"
        echo "  --all       Clean all safe caches with a single confirmation prompt"
        echo "  --docker    Clean Docker unused images & build cache only"
        echo "  --pkg       Clean npm, pnpm, yarn, and NuGet package caches"
        return 0
        ;;
      *)
        echo "Unknown option: $1 (run 'diskspace clean --help' for options)"
        return 1
        ;;
    esac
  done

  # Probe available targets and their sizes
  local sz_docker_images="0B"
  local sz_docker_builder="0B"
  local sz_npm="0B"
  local sz_nuget="0B"
  local sz_brew="0B"
  local sz_pnpm="0B"
  local sz_yarn="0B"
  local sz_xcode="0B"
  local sz_trash="0B"

  printf "%s%sScanning reclaimable caches and disk hogs...%s\n" "$DS_DIM" "$DS_CYAN" "$DS_RESET"

  # 1. Docker
  local docker_available=0
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker_available=1
    local d_images d_builder
    d_images=$(docker system df --format '{{json .}}' 2>/dev/null | grep '"Type":"Images"' | sed -E 's/.*"Reclaimable":"([^"]+)".*/\1/' || echo "0B")
    d_builder=$(docker system df --format '{{json .}}' 2>/dev/null | grep '"Type":"Build Cache"' | sed -E 's/.*"Reclaimable":"([^"]+)".*/\1/' || echo "0B")
    [[ -n "$d_images" ]] && sz_docker_images="$d_images"
    [[ -n "$d_builder" ]] && sz_docker_builder="$d_builder"
  fi

  # 2. Node / npm
  if [[ -d "$HOME/.npm" ]]; then
    sz_npm=$(_ds_get_dir_size "$HOME/.npm")
  fi

  # 3. pnpm
  if command -v pnpm >/dev/null 2>&1; then
    local pnpm_store
    pnpm_store=$(pnpm store path 2>/dev/null || echo "")
    if [[ -n "$pnpm_store" && -d "$pnpm_store" ]]; then
      sz_pnpm=$(_ds_get_dir_size "$pnpm_store")
    fi
  fi

  # 4. Yarn
  if [[ -d "$HOME/Library/Caches/Yarn" ]]; then
    sz_yarn=$(_ds_get_dir_size "$HOME/Library/Caches/Yarn")
  elif [[ -d "$HOME/.cache/yarn" ]]; then
    sz_yarn=$(_ds_get_dir_size "$HOME/.cache/yarn")
  fi

  # 5. .NET / NuGet
  if [[ -d "$HOME/.nuget/packages" ]]; then
    sz_nuget=$(_ds_get_dir_size "$HOME/.nuget/packages")
  elif [[ -d "$HOME/.nuget" ]]; then
    sz_nuget=$(_ds_get_dir_size "$HOME/.nuget")
  fi

  # 6. Homebrew
  if command -v brew >/dev/null 2>&1; then
    local brew_cache
    brew_cache=$(brew --cache 2>/dev/null || echo "")
    if [[ -n "$brew_cache" && -d "$brew_cache" ]]; then
      sz_brew=$(_ds_get_dir_size "$brew_cache")
    fi
  fi

  # 7. Xcode DerivedData
  if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
    sz_xcode=$(_ds_get_dir_size "$HOME/Library/Developer/Xcode/DerivedData")
  fi

  # 8. Trash
  if [[ -d "$HOME/.Trash" ]]; then
    sz_trash=$(_ds_get_dir_size "$HOME/.Trash")
  elif [[ -d "$HOME/.local/share/Trash" ]]; then
    sz_trash=$(_ds_get_dir_size "$HOME/.local/share/Trash")
  fi

  # If dry run mode, print summary and exit
  if [[ "$dry_run" -eq 1 ]]; then
    printf "\n%s%s=== Dry-Run: Reclaimable Space Summary ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
    printf "%-32s %s\n" "CATEGORY" "ESTIMATED RECLAIMABLE"
    printf "%s\n" "--------------------------------------------------------"
    if [[ $docker_available -eq 1 ]]; then
      printf "%-32s %s\n" "Docker Unused Images" "$sz_docker_images"
      printf "%-32s %s\n" "Docker Build Cache" "$sz_docker_builder"
    else
      printf "%-32s %s\n" "Docker" "Daemon not running / unavailable"
    fi
    printf "%-32s %s\n" "NPM Cache (~/.npm)" "$sz_npm"
    [[ "$sz_pnpm" != "0B" ]] && printf "%-32s %s\n" "pnpm Store" "$sz_pnpm"
    [[ "$sz_yarn" != "0B" ]] && printf "%-32s %s\n" "Yarn Cache" "$sz_yarn"
    printf "%-32s %s\n" ".NET NuGet Cache (~/.nuget)" "$sz_nuget"
    command -v brew >/dev/null 2>&1 && printf "%-32s %s\n" "Homebrew Cache" "$sz_brew"
    [[ "$sz_xcode" != "0B" ]] && printf "%-32s %s\n" "Xcode DerivedData" "$sz_xcode"
    [[ "$sz_trash" != "0B" ]] && printf "%-32s %s\n" "User Trash" "$sz_trash"
    printf "\n%sNo files were deleted.%s To clean, run: %sdiskspace clean%s\n\n" \
      "$DS_DIM" "$DS_RESET" "$DS_BOLD" "$DS_RESET"
    return 0
  fi

  # Helper actions for cleaning each category
  _clean_docker() {
    printf "%s🧹 Cleaning Docker build cache and unused images...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    docker builder prune -f
    docker image prune -a -f
    printf "%s✔ Docker cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_npm() {
    printf "%s🧹 Cleaning npm cache...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    npm cache clean --force 2>/dev/null || rm -rf "$HOME/.npm/_cacache"
    printf "%s✔ npm cache cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_pnpm() {
    printf "%s🧹 Pruning pnpm store...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    pnpm store prune 2>/dev/null || true
    printf "%s✔ pnpm store pruned.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_yarn() {
    printf "%s🧹 Cleaning Yarn cache...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    yarn cache clean --all 2>/dev/null || rm -rf "$HOME/Library/Caches/Yarn" "$HOME/.cache/yarn"
    printf "%s✔ Yarn cache cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_nuget() {
    printf "%s🧹 Clearing .NET NuGet caches...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    if command -v dotnet >/dev/null 2>&1; then
      dotnet nuget locals all --clear
    else
      rm -rf "$HOME/.nuget/packages"
    fi
    printf "%s✔ NuGet cache cleared.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_brew() {
    printf "%s🧹 Cleaning Homebrew downloads and cache...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    brew cleanup --prune=all -s 2>/dev/null || true
    local bc
    bc=$(brew --cache 2>/dev/null)
    [[ -n "$bc" && -d "$bc" ]] && rm -rf "$bc"/* 2>/dev/null || true
    printf "%s✔ Homebrew cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_xcode() {
    printf "%s🧹 Removing Xcode DerivedData...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/* 2>/dev/null || true
    printf "%s✔ Xcode DerivedData removed.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  _clean_trash() {
    printf "%s🧹 Emptying Trash...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
    rm -rf "$HOME/.Trash"/* 2>/dev/null || true
    rm -rf "$HOME/.local/share/Trash"/* 2>/dev/null || true
    printf "%s✔ Trash emptied.%s\n\n" "$DS_GREEN" "$DS_RESET"
  }

  # Direct execution modes
  if [[ "$mode" == "docker" ]]; then
    if [[ $docker_available -eq 1 ]]; then
      _clean_docker
    else
      echo "Docker is not currently running."
    fi
    return 0
  fi

  if [[ "$mode" == "pkg" ]]; then
    _clean_npm
    [[ "$sz_pnpm" != "0B" ]] && _clean_pnpm
    [[ "$sz_yarn" != "0B" ]] && _clean_yarn
    _clean_nuget
    return 0
  fi

  if [[ "$mode" == "all" ]]; then
    printf "\n%sClean all safe caches and build artifacts?%s (y/N): " "$DS_BOLD$DS_YELLOW" "$DS_RESET"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      [[ $docker_available -eq 1 ]] && _clean_docker
      _clean_npm
      [[ "$sz_pnpm" != "0B" ]] && _clean_pnpm
      [[ "$sz_yarn" != "0B" ]] && _clean_yarn
      _clean_nuget
      command -v brew >/dev/null 2>&1 && _clean_brew
      [[ "$sz_xcode" != "0B" ]] && _clean_xcode
      _clean_trash
      printf "%sAll targets cleaned successfully!%s\n\n" "$DS_BOLD$DS_GREEN" "$DS_RESET"
      _diskspace_status
    else
      echo "Cleanup aborted."
    fi
    return 0
  fi

  # Interactive Mode: Build items list
  local items=()
  [[ $docker_available -eq 1 ]] && items+=("docker::Docker Unused Images ($sz_docker_images) & Build Cache ($sz_docker_builder)")
  items+=("npm::Node / npm Cache (~/.npm: $sz_npm)")
  [[ "$sz_pnpm" != "0B" ]] && items+=("pnpm::pnpm Store Cache ($sz_pnpm)")
  [[ "$sz_yarn" != "0B" ]] && items+=("yarn::Yarn Cache ($sz_yarn)")
  items+=("nuget::.NET NuGet Global Cache (~/.nuget: $sz_nuget)")
  command -v brew >/dev/null 2>&1 && items+=("brew::Homebrew Cache & Stale Formulae ($sz_brew)")
  [[ "$sz_xcode" != "0B" ]] && items+=("xcode::Xcode DerivedData ($sz_xcode)")
  [[ "$sz_trash" != "0B" ]] && items+=("trash::User Trash ($sz_trash)")

  # If fzf is available and interactive, present rich multi-select
  if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
    local fzf_input=""
    for entry in "${items[@]}"; do
      local id="${entry%%::*}"
      local label="${entry#*::}"
      fzf_input+="$id :: $label"$'\n'
    done

    local selected
    selected=$(echo -n "$fzf_input" | fzf -m \
      --header="Select items to clean with TAB or SPACE, then press ENTER (ESC to cancel):" \
      --prompt="Clean > " \
      --delimiter=" :: " \
      --with-nth=2 \
      --height=40% \
      --reverse)

    if [[ -z "$selected" ]]; then
      echo "Cleanup cancelled."
      return 0
    fi

    echo ""
    while IFS= read -r line; do
      local item_id="${line%% :: *}"
      case "$item_id" in
        docker) _clean_docker ;;
        npm)    _clean_npm ;;
        pnpm)   _clean_pnpm ;;
        yarn)   _clean_yarn ;;
        nuget)  _clean_nuget ;;
        brew)   _clean_brew ;;
        xcode)  _clean_xcode ;;
        trash)  _clean_trash ;;
      esac
    done <<< "$selected"

    printf "%sSelected cleaning completed!%s\n\n" "$DS_BOLD$DS_GREEN" "$DS_RESET"
    _diskspace_status
    return 0
  fi

  # Fallback terminal menu if fzf is not interactive
  printf "\n%s%s=== Select Items to Clean ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
  local idx=1
  for entry in "${items[@]}"; do
    local label="${entry#*::}"
    printf "  [%d] %s\n" "$idx" "$label"
    ((idx++))
  done
  printf "  [a] Clean All Above\n"
  printf "  [q] Cancel\n\n"

  printf "Enter choices separated by spaces (e.g. 1 2 3 or a): "
  read -r choices

  if [[ "$choices" == "q" || -z "$choices" ]]; then
    echo "Cleanup cancelled."
    return 0
  fi

  if [[ "$choices" == "a" ]]; then
    [[ $docker_available -eq 1 ]] && _clean_docker
    _clean_npm
    [[ "$sz_pnpm" != "0B" ]] && _clean_pnpm
    [[ "$sz_yarn" != "0B" ]] && _clean_yarn
    _clean_nuget
    command -v brew >/dev/null 2>&1 && _clean_brew
    [[ "$sz_xcode" != "0B" ]] && _clean_xcode
    _clean_trash
    printf "%sAll targets cleaned!%s\n\n" "$DS_BOLD$DS_GREEN" "$DS_RESET"
    _diskspace_status
    return 0
  fi

  for choice in $choices; do
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      local curr=1
      for entry in "${items[@]}"; do
        if [[ "$curr" -eq "$choice" ]]; then
          local target_id="${entry%%::*}"
          case "$target_id" in
            docker) _clean_docker ;;
            npm)    _clean_npm ;;
            pnpm)   _clean_pnpm ;;
            yarn)   _clean_yarn ;;
            nuget)  _clean_nuget ;;
            brew)   _clean_brew ;;
            xcode)  _clean_xcode ;;
            trash)  _clean_trash ;;
          esac
        fi
        ((curr++))
      done
    fi
  done

  printf "%sSelected cleaning completed!%s\n\n" "$DS_BOLD$DS_GREEN" "$DS_RESET"
  _diskspace_status
}

# ------------------------------------------------------------------------------
# Main Dispatcher
# ------------------------------------------------------------------------------
diskspace() {
  local cmd="${1:-status}"
  case "$cmd" in
    status)
      _diskspace_status
      ;;
    top|analyze)
      shift
      _diskspace_top "$@"
      ;;
    clean|cleanup)
      shift
      _diskspace_clean "$@"
      ;;
    help|--help|-h)
      _ds_setup_colors
      printf "%s%sdiskspace%s — Intelligent Disk Space Inspector & Cleaner\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
      printf "%sUsage:%s\n" "$DS_BOLD" "$DS_RESET"
      echo "  diskspace                     Show disk usage with color capacity bars and status alerts"
      echo "  diskspace status              Explicit status overview (same as bare diskspace)"
      echo "  diskspace top [path] [n]      Show top [n] largest directories in [path] (default: \$HOME, 10)"
      echo "  diskspace clean               Interactive multi-select cleanup menu (Docker, npm, NuGet, caches)"
      echo "  diskspace clean --dry-run     Estimate reclaimable space without deleting anything"
      echo "  diskspace clean --all         Clean all safe developer caches"
      echo "  diskspace clean --docker      Clean Docker images and build cache only"
      echo "  diskspace clean --pkg         Clean npm, pnpm, yarn, and NuGet package caches"
      echo "  diskspace help                Show this help message"
      ;;
    *)
      # If first argument is a directory or path, redirect to top
      if [[ -d "$cmd" ]]; then
        _diskspace_top "$@"
      else
        echo "Unknown subcommand: $cmd"
        echo "Run 'diskspace help' for available options."
        return 1
      fi
      ;;
  esac
}
