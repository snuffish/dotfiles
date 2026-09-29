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
# Helper: Render `df -h` output as a colored capacity table
#   $1 = column holding the mount point (macOS: 9, GNU: 6)
#   $2 = 1 to apply APFS filtering (skip synthetic /System/Volumes/* volumes)
# ------------------------------------------------------------------------------
_ds_render_df() {
  awk -v mcol="$1" -v apfs="$2" -v bold="$DS_BOLD" -v reset="$DS_RESET" \
      -v red="$DS_RED" -v yellow="$DS_YELLOW" -v green="$DS_GREEN" '
  BEGIN {
    printf "%-28s %-7s %-7s %-7s %-6s   %-14s   %s\n", "MOUNT", "SIZE", "USED", "AVAIL", "CAP", "USAGE", "STATUS"
    print "--------------------------------------------------------------------------------"
  }
  NR == 1 { next }
  apfs && ($1 !~ /^\/dev\// || $mcol ~ /\/System\/Volumes\/(VM|Preboot|Update|xarts|iSCPreboot|Hardware)/) { next }
  # Btrfs subvolumes / bind mounts expose the same device several times; show it once
  seen[$1]++ { next }
  {
    cap_num = $5 + 0

    filled = int(cap_num / 10)
    bar = ""
    for (i = 1; i <= 10; i++) bar = bar (i <= filled ? "■" : "·")

    mount = $mcol
    if (apfs && mount == "/System/Volumes/Data") mount = "/System/Volumes/Data (User)"
    else if (apfs && mount == "/")               mount = "/ (System)"

    if (cap_num >= 90) {
      c_start = red bold;   status_tag = red bold "🚨 CRITICAL" reset
    } else if (cap_num >= 75) {
      c_start = yellow bold; status_tag = yellow bold "⚠️  LOW" reset
    } else {
      c_start = green;      status_tag = green "🟢 OK" reset
    }

    printf "%-28s %-7s %-7s %-7s %s%-6s%s   %s[%s]%s   %s\n", mount, $2, $3, $4, c_start, $5, reset, c_start, bar, reset, status_tag
  }'
}

# ------------------------------------------------------------------------------
# Helper: Remove the contents of a directory (including dotfiles) but keep it
# ------------------------------------------------------------------------------
_ds_empty_dir() {
  [[ -d "$1" ]] && find "$1" -mindepth 1 -delete 2>/dev/null
  return 0
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
    df -h | _ds_render_df 9 1
  else
    df -h -x squashfs -x tmpfs -x devtmpfs -x overlay -x efivarfs 2>/dev/null | _ds_render_df 6 0
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
  # Strip trailing slash so the "(Total)" row still matches du's output
  [[ "$target_dir" != "/" ]] && target_dir="${target_dir%/}"

  if [[ ! -d "$target_dir" ]]; then
    echo "Error: Directory '$target_dir' does not exist." >&2
    return 1
  fi

  if [[ ! "$count" =~ ^[0-9]+$ ]]; then
    echo "Error: Count must be a positive integer (got '$count')." >&2
    return 1
  fi

  printf "%s%sScanning top %s largest directories in: %s%s%s\n\n" \
    "$DS_BOLD" "$DS_CYAN" "$count" "$DS_RESET$DS_BOLD" "$target_dir" "$DS_RESET"

  printf "%-10s %s\n" "SIZE" "DIRECTORY"
  printf "%s\n" "--------------------------------------------------------"

  # -d 1 and -x (stay on one filesystem) are supported by both BSD and GNU du
  du -x -d 1 -h "$target_dir" 2>/dev/null | sort -hr | head -n "$((count + 1))" | while IFS=$'\t' read -r sz dir; do
    if [[ "$dir" == "$target_dir" ]]; then
      printf "%s%-10s %s (Total)%s\n" "$DS_BOLD$DS_BLUE" "$sz" "$dir" "$DS_RESET"
    else
      printf "%-10s %s\n" "$sz" "$dir"
    fi
  done
  printf "\n"
}

# ------------------------------------------------------------------------------
# Cleanup Actions (one per category id)
# ------------------------------------------------------------------------------
_ds_clean_docker() {
  printf "%s🧹 Cleaning Docker build cache and unused images...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  docker builder prune -f
  docker image prune -a -f
  printf "%s✔ Docker cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_npm() {
  printf "%s🧹 Cleaning npm cache...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  npm cache clean --force 2>/dev/null || rm -rf "$HOME/.npm/_cacache"
  printf "%s✔ npm cache cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_pnpm() {
  printf "%s🧹 Pruning pnpm store...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  pnpm store prune 2>/dev/null || true
  printf "%s✔ pnpm store pruned.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_yarn() {
  printf "%s🧹 Cleaning Yarn cache...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  yarn cache clean --all 2>/dev/null || rm -rf "$HOME/Library/Caches/Yarn" "$HOME/.cache/yarn"
  printf "%s✔ Yarn cache cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_nuget() {
  printf "%s🧹 Clearing .NET NuGet caches...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  if command -v dotnet >/dev/null 2>&1; then
    dotnet nuget locals all --clear
  else
    rm -rf "$HOME/.nuget/packages"
  fi
  printf "%s✔ NuGet cache cleared.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_brew() {
  printf "%s🧹 Cleaning Homebrew downloads and cache...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  brew cleanup --prune=all -s 2>/dev/null || true
  _ds_empty_dir "$(brew --cache 2>/dev/null)"
  printf "%s✔ Homebrew cleaned.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_xcode() {
  printf "%s🧹 Removing Xcode DerivedData...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  _ds_empty_dir "$HOME/Library/Developer/Xcode/DerivedData"
  printf "%s✔ Xcode DerivedData removed.%s\n\n" "$DS_GREEN" "$DS_RESET"
}

_ds_clean_trash() {
  printf "%s🧹 Emptying Trash...%s\n" "$DS_BOLD$DS_BLUE" "$DS_RESET"
  _ds_empty_dir "$HOME/.Trash"
  _ds_empty_dir "$HOME/.local/share/Trash"
  printf "%s✔ Trash emptied.%s\n\n" "$DS_GREEN" "$DS_RESET"
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
      --dry-run) dry_run=1 ;;
      --all)     mode="all" ;;
      --docker)  mode="docker" ;;
      --pkg)     mode="pkg" ;;
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
        echo "Unknown option: $1 (run 'diskspace clean --help' for options)" >&2
        return 1
        ;;
    esac
    shift
  done

  # Probe available targets and their sizes ("0B" = not present)
  local sz_docker_images="0B" sz_docker_builder="0B"
  local sz_npm="0B" sz_pnpm="0B" sz_yarn="0B" sz_nuget="0B"
  local sz_brew="0B" sz_xcode="0B" sz_trash="0B"
  local has_brew=0
  command -v brew >/dev/null 2>&1 && has_brew=1

  printf "%s%sScanning reclaimable caches and disk hogs...%s\n" "$DS_DIM" "$DS_CYAN" "$DS_RESET"

  # 1. Docker
  local docker_available=0
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker_available=1
    local d_df d_images d_builder
    d_df=$(docker system df --format '{{.Type}}\t{{.Reclaimable}}' 2>/dev/null)
    d_images=$(awk -F'\t' '$1 == "Images" {print $2}' <<< "$d_df")
    d_builder=$(awk -F'\t' '$1 == "Build Cache" {print $2}' <<< "$d_df")
    [[ -n "$d_images" ]] && sz_docker_images="$d_images"
    [[ -n "$d_builder" ]] && sz_docker_builder="$d_builder"
  fi

  # 2. Node / npm
  sz_npm=$(_ds_get_dir_size "$HOME/.npm")

  # 3. pnpm
  if command -v pnpm >/dev/null 2>&1; then
    sz_pnpm=$(_ds_get_dir_size "$(pnpm store path 2>/dev/null)")
  fi

  # 4. Yarn
  if [[ -d "$HOME/Library/Caches/Yarn" ]]; then
    sz_yarn=$(_ds_get_dir_size "$HOME/Library/Caches/Yarn")
  else
    sz_yarn=$(_ds_get_dir_size "$HOME/.cache/yarn")
  fi

  # 5. .NET / NuGet
  if [[ -d "$HOME/.nuget/packages" ]]; then
    sz_nuget=$(_ds_get_dir_size "$HOME/.nuget/packages")
  else
    sz_nuget=$(_ds_get_dir_size "$HOME/.nuget")
  fi

  # 6. Homebrew
  if [[ $has_brew -eq 1 ]]; then
    sz_brew=$(_ds_get_dir_size "$(brew --cache 2>/dev/null)")
  fi

  # 7. Xcode DerivedData
  sz_xcode=$(_ds_get_dir_size "$HOME/Library/Developer/Xcode/DerivedData")

  # 8. Trash
  if [[ -d "$HOME/.Trash" ]]; then
    sz_trash=$(_ds_get_dir_size "$HOME/.Trash")
  else
    sz_trash=$(_ds_get_dir_size "$HOME/.local/share/Trash")
  fi

  # Build the list of applicable targets: "id::label"
  local -a items=()
  [[ $docker_available -eq 1 ]] && items+=("docker::Docker Unused Images ($sz_docker_images) & Build Cache ($sz_docker_builder)")
  [[ "$sz_npm"   != "0B" ]] && items+=("npm::Node / npm Cache (~/.npm: $sz_npm)")
  [[ "$sz_pnpm"  != "0B" ]] && items+=("pnpm::pnpm Store Cache ($sz_pnpm)")
  [[ "$sz_yarn"  != "0B" ]] && items+=("yarn::Yarn Cache ($sz_yarn)")
  [[ "$sz_nuget" != "0B" ]] && items+=("nuget::.NET NuGet Global Cache (~/.nuget: $sz_nuget)")
  [[ $has_brew -eq 1 ]]     && items+=("brew::Homebrew Cache & Stale Formulae ($sz_brew)")
  [[ "$sz_xcode" != "0B" ]] && items+=("xcode::Xcode DerivedData ($sz_xcode)")
  [[ "$sz_trash" != "0B" ]] && items+=("trash::User Trash ($sz_trash)")

  local entry
  if [[ "$dry_run" -eq 1 ]]; then
    printf "\n%s%s=== Dry-Run: Reclaimable Space Summary ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
    [[ $docker_available -eq 0 ]] && printf "%sDocker: daemon not running / unavailable%s\n" "$DS_DIM" "$DS_RESET"
    if [[ ${#items[@]} -eq 0 ]]; then
      echo "Nothing reclaimable found."
    else
      for entry in "${items[@]}"; do
        printf "  • %s\n" "${entry#*::}"
      done
    fi
    printf "\n%sNo files were deleted.%s To clean, run: %sdiskspace clean%s\n\n" \
      "$DS_DIM" "$DS_RESET" "$DS_BOLD" "$DS_RESET"
    return 0
  fi

  if [[ ${#items[@]} -eq 0 ]]; then
    echo "Nothing reclaimable found."
    return 0
  fi

  # Selected ids to clean, filled by the chosen mode below
  local -a selected_ids=()
  local id

  case "$mode" in
    docker)
      if [[ $docker_available -eq 0 ]]; then
        echo "Docker is not currently running." >&2
        return 1
      fi
      selected_ids=(docker)
      ;;
    pkg)
      for entry in "${items[@]}"; do
        id="${entry%%::*}"
        [[ "$id" =~ ^(npm|pnpm|yarn|nuget)$ ]] && selected_ids+=("$id")
      done
      ;;
    all)
      printf "\n%sClean all safe caches and build artifacts?%s (y/N): " "$DS_BOLD$DS_YELLOW" "$DS_RESET"
      local confirm
      read -r confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cleanup aborted."
        return 0
      fi
      for entry in "${items[@]}"; do selected_ids+=("${entry%%::*}"); done
      ;;
    interactive)
      if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
        local selected line
        selected=$(printf "%s\n" "${items[@]}" | fzf -m \
          --header="Select items with TAB or SPACE, then press ENTER (ESC to cancel):" \
          --prompt="Clean > " \
          --delimiter="::" \
          --with-nth=2 \
          --bind="space:toggle" \
          --height=40% \
          --reverse)
        while IFS= read -r line; do
          [[ -n "$line" ]] && selected_ids+=("${line%%::*}")
        done <<< "$selected"
      else
        # Fallback numbered menu when fzf is missing or not interactive
        printf "\n%s%s=== Select Items to Clean ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
        local idx=1
        for entry in "${items[@]}"; do
          printf "  [%d] %s\n" "$idx" "${entry#*::}"
          idx=$((idx + 1))
        done
        printf "  [a] Clean All Above\n"
        printf "  [q] Cancel\n\n"
        printf "Enter choices separated by spaces (e.g. 1 2 3 or a): "
        local choices choice curr
        read -r choices

        # Split on spaces/commas via tr so it works identically in bash and zsh
        while IFS= read -r choice; do
          [[ "$choice" == "q" ]] && { selected_ids=(); break; }
          curr=1
          for entry in "${items[@]}"; do
            if [[ "$choice" == "a" || "$choice" == "$curr" ]]; then
              selected_ids+=("${entry%%::*}")
            fi
            curr=$((curr + 1))
          done
        done < <(printf "%s" "$choices" | tr -s ' ,' '\n\n')
      fi
      ;;
  esac

  if [[ ${#selected_ids[@]} -eq 0 ]]; then
    echo "Cleanup cancelled."
    return 0
  fi

  echo ""
  # De-duplicate (e.g. "1 1" or "a 2") while preserving order
  local done_ids=" "
  for id in "${selected_ids[@]}"; do
    [[ "$done_ids" == *" $id "* ]] && continue
    done_ids+="$id "
    "_ds_clean_$id"
  done

  printf "%sCleaning completed!%s\n\n" "$DS_BOLD$DS_GREEN" "$DS_RESET"
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
        echo "Unknown subcommand: $cmd" >&2
        echo "Run 'diskspace help' for available options." >&2
        return 1
      fi
      ;;
  esac
}
