#!/usr/bin/env bash

# ==============================================================================
# diskspace.bash — Intelligent Disk Space Inspector & Interactive Cleaner
# Supports macOS (APFS aware), Linux, and Windows (WSL/Git Bash).
# Compatible with both Bash and Zsh.
# ==============================================================================

# Unset any stale alias if previously defined
unalias diskspace 2>/dev/null || true

# Items smaller than this (in KB) are hidden from the clean menus (default 10 MB)
: "${DS_MIN_KB:=10240}"
# Space-separated device paths to never report as idle (e.g. "/dev/sdb1")
: "${DS_IGNORE_DEVICES:=}"

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
# Helper: Detect platform ("mac" | "linux" | "other"), honoring ENV_PROFILE
# ------------------------------------------------------------------------------
_ds_os() {
  case "${ENV_PROFILE:-$(uname -s)}" in
    Mac|Darwin) echo "mac" ;;
    Linux)      echo "linux" ;;
    *)          echo "other" ;;
  esac
}

# ------------------------------------------------------------------------------
# Size Helpers — everything is measured in KB so it can be summed and sorted
# ------------------------------------------------------------------------------

# Sum of the on-disk size (KB) of every existing path given; 0 if none exist
_ds_dir_kb() {
  local p sz kb=0
  for p in "$@"; do
    [[ -n "$p" && -e "$p" ]] || continue
    sz=$(du -sk "$p" 2>/dev/null | awk '{print $1; exit}')
    kb=$((kb + ${sz:-0}))
  done
  echo "$kb"
}

# KB → human readable (e.g. 1536 → 1.5M)
_ds_fmt_kb() {
  awk -v kb="${1:-0}" 'BEGIN {
    split("K M G T", unit, " ")
    v = kb; i = 1
    while (v >= 1024 && i < 4) { v /= 1024; i++ }
    fmt = (i > 1 && v < 10) ? "%.1f%s" : "%d%s"
    printf fmt, v, unit[i]
  }'
}

# Human size string → KB. $2 is the unit base: 1000 (Docker) or 1024 (journalctl)
_ds_parse_size() {
  awk -v s="$1" -v base="${2:-1000}" 'BEGIN {
    if (!match(s, /^[0-9.]+/)) { print 0; exit }
    n = substr(s, 1, RLENGTH)
    u = toupper(substr(s, RLENGTH + 1, 1))
    m = (u == "T") ? base^4 : (u == "G") ? base^3 : (u == "M") ? base^2 : (u == "K") ? base : 1
    printf "%d\n", n * m / 1024
  }'
}

# Used KB across the filesystems holding / and $HOME (for the "Freed" delta)
_ds_used_kb() {
  df -kP / "$HOME" 2>/dev/null | awk 'NR > 1 && !seen[$1]++ { s += $3 } END { print s + 0 }'
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
# Storage Layout Diagnostics (Linux) — idle disks & data dirs stuck on root
# ------------------------------------------------------------------------------

# Filesystem source device backing a path (walks up to the nearest existing,
# accessible ancestor, since data dirs are often root-only)
_ds_path_source() {
  local p="$1"
  while [[ -n "$p" && "$p" != "/" ]]; do
    df -P "$p" >/dev/null 2>&1 && break
    p="${p%/*}"
  done
  df -P "${p:-/}" 2>/dev/null | awk 'NR == 2 { print $1 }'
}

# Docker's data root: daemon.json → running daemon → default
_ds_docker_root() {
  local root=""
  [[ -r /etc/docker/daemon.json ]] &&
    root=$(sed -nE 's/.*"data-root"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' /etc/docker/daemon.json | head -n 1)
  if [[ -z "$root" ]] && command -v docker >/dev/null 2>&1; then
    root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null)
  fi
  [[ -z "$root" && -d /var/lib/docker ]] && root="/var/lib/docker"
  echo "$root"
}

# Ollama model dir: shell env → systemd service env → default locations
_ds_ollama_models() {
  local dir="${OLLAMA_MODELS:-}"
  if [[ -z "$dir" ]] && command -v systemctl >/dev/null 2>&1; then
    dir=$(systemctl show ollama -p Environment --value 2>/dev/null | tr ' ' '\n' | sed -n 's/^OLLAMA_MODELS=//p')
  fi
  if [[ -z "$dir" ]]; then
    local d
    for d in "$HOME/.ollama/models" /usr/share/ollama/.ollama/models; do
      [[ -d "$d" ]] && { dir="$d"; break; }
    done
  fi
  echo "$dir"
}

_ds_storage_warnings() {
  [[ "$(_ds_os)" == "linux" ]] && command -v lsblk >/dev/null 2>&1 || return 0

  local root_src
  root_src=$(df -P / 2>/dev/null | awk 'NR == 2 { print $1 }')

  # Partitions >= 32G that carry a real filesystem: "name|size|fstype|mountpoints"
  local disks
  disks=$(lsblk -bnpPo NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS 2>/dev/null | awk '
    {
      delete f
      while (match($0, /[A-Z]+="[^"]*"/)) {
        kv = substr($0, RSTART, RLENGTH); $0 = substr($0, RSTART + RLENGTH)
        k = kv; sub(/=.*/, "", k); v = kv; sub(/^[^=]*="/, "", v); sub(/"$/, "", v)
        f[k] = v
      }
      if (f["TYPE"] !~ /^(part|disk|crypt|lvm)$/) next
      if (f["FSTYPE"] == "" || f["FSTYPE"] ~ /^(swap|crypto_LUKS|LVM2_member|linux_raid_member|squashfs)$/) next
      if (f["SIZE"] + 0 < 32 * 1024^3) next
      print f["NAME"] "|" f["SIZE"] "|" f["FSTYPE"] "|" f["MOUNTPOINTS"]
    }')

  local -a warnings=()
  local has_other_disk=0 line name size fstype mounts target

  while IFS='|' read -r name size fstype mounts; do
    [[ -z "$name" || "$name" == "$root_src" ]] && continue
    [[ " $DS_IGNORE_DEVICES " == *" $name "* ]] && continue
    has_other_disk=1
    [[ -n "$mounts" ]] && continue
    line="$name ($(_ds_fmt_kb $((size / 1024))) $fstype) is not mounted"
    target=$(findmnt --fstab -no TARGET -S "$name" 2>/dev/null | head -n 1)
    [[ -n "$target" ]] && line+=" — fstab/automount target: $target"
    warnings+=("$line")
  done <<< "$disks"

  # Data dirs on the root device only matter when there's somewhere else to put them
  if [[ $has_other_disk -eq 1 ]]; then
    local label dir
    while IFS='|' read -r label dir; do
      [[ -n "$dir" ]] || continue
      [[ "$(_ds_path_source "$dir")" == "$root_src" ]] &&
        warnings+=("$label ($dir) is stored on the root disk ($root_src)")
    done <<< "Docker data|$(_ds_docker_root)
Ollama models|$(_ds_ollama_models)"
  fi

  [[ ${#warnings[@]} -eq 0 ]] && return 0

  printf "%s%s🧭 Storage layout%s\n" "$DS_BOLD" "$DS_YELLOW" "$DS_RESET"
  for line in "${warnings[@]}"; do
    printf "   %s⚠%s %s\n" "$DS_YELLOW" "$DS_RESET" "$line"
  done
  printf "   → See %sdiskspace help storage%s for how to relocate data.\n\n" "$DS_BOLD" "$DS_RESET"
}

_ds_help_storage() {
  _ds_setup_colors
  printf "%s%sRelocating data to another disk%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
  cat <<'EOF'
Mounting a disk over a non-empty directory HIDES its contents but does not free
the space. Move the data first:

  1. Measure:       sudo du -xsh <data-dir>/* | sort -h
  2. Stop users:    sudo systemctl stop docker docker.socket ollama
  3. Mount target:  give the disk its own empty mountpoint in /etc/fstab
                    (e.g. /mnt/data), then: sudo mount -a
  4. Copy:          sudo rsync -aHAX --info=progress2 <data-dir>/ /mnt/data/<name>/
  5. Repoint:       Docker → "data-root" in /etc/docker/daemon.json
                    Ollama → OLLAMA_MODELS via: sudo systemctl edit ollama
  6. Verify:        sudo systemctl daemon-reload && sudo systemctl start docker ollama
                    docker info | grep 'Root Dir'; ollama list; df -h /
  7. Clean up:      only after verifying, remove the old copy from the root disk
EOF
  echo ""
}

# ------------------------------------------------------------------------------
# Subcommand: status (Default) — Accurate Mounts & Visual Capacity Bar
# ------------------------------------------------------------------------------
_diskspace_status() {
  _ds_setup_colors

  printf "%s%s=== Disk Space Overview ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"

  local os_type
  os_type=$(_ds_os)

  if [[ "$os_type" == "mac" ]]; then
    df -h | _ds_render_df 9 1
  else
    df -h -x squashfs -x tmpfs -x devtmpfs -x overlay -x efivarfs 2>/dev/null | _ds_render_df 6 0
  fi

  # Determine if user data volume is under pressure
  local data_cap
  if [[ "$os_type" == "mac" ]]; then
    data_cap=$(df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {sub(/%/,"",$5); print $5}')
  else
    data_cap=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {sub(/%/,"",$5); print $5}')
  fi

  data_cap=${data_cap:-0}

  printf "\n"
  _ds_storage_warnings

  if [[ $data_cap -ge 90 ]]; then
    printf "%s%s🚨 WARNING: Disk is critically full (%s%% capacity)!%s\n" "$DS_BOLD" "$DS_RED" "$data_cap" "$DS_RESET"
    printf "   • Run %sdiskspace clean%s to free up caches & unused Docker containers/images\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace clean --dry-run%s to preview reclaimable space\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace top%s to locate large folders in %s\n" "$DS_BOLD" "$DS_RESET" "$HOME"
    printf "   • Run %sdiskspace limits%s to stop caches and logs from growing back\n\n" "$DS_BOLD" "$DS_RESET"
  elif [[ $data_cap -ge 75 ]]; then
    printf "%s%s⚠️  NOTICE: Disk space is getting low (%s%% capacity).%s\n" "$DS_BOLD" "$DS_YELLOW" "$data_cap" "$DS_RESET"
    printf "   • Run %sdiskspace clean%s to interactively reclaim space\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace top%s to find large folders\n" "$DS_BOLD" "$DS_RESET"
    printf "   • Run %sdiskspace limits%s to stop caches and logs from growing back\n\n" "$DS_BOLD" "$DS_RESET"
  else
    printf "%s💡 Tip:%s Use %sdiskspace clean%s to clean caches or %sdiskspace top%s to scan large folders.\n\n" \
      "$DS_DIM" "$DS_RESET" "$DS_BOLD" "$DS_RESET" "$DS_BOLD" "$DS_RESET"
  fi
}

# ------------------------------------------------------------------------------
# Subcommand: limits — Report missing retention policies (read-only)
# ------------------------------------------------------------------------------
_diskspace_limits() {
  _ds_setup_colors
  printf "%s%s=== Retention Limits ===%s\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
  printf "%sCaches and logs grow back after cleaning unless they are capped.%s\n\n" "$DS_DIM" "$DS_RESET"

  local missing=0

  _ds_limit_ok()   { printf "  %s✔%s %s\n" "$DS_GREEN" "$DS_RESET" "$1"; }
  _ds_limit_warn() {
    missing=$((missing + 1))
    printf "  %s⚠%s %s\n" "$DS_YELLOW" "$DS_RESET" "$1"
    shift
    local fix
    for fix in "$@"; do printf "      %s%s%s\n" "$DS_DIM" "$fix" "$DS_RESET"; done
  }

  # systemd journal
  if command -v journalctl >/dev/null 2>&1; then
    local max_use
    max_use=$(systemd-analyze cat-config systemd/journald.conf 2>/dev/null |
      sed -nE 's/^[[:space:]]*SystemMaxUse=[[:space:]]*([^[:space:]]+).*/\1/p' | tail -n 1)
    if [[ -n "$max_use" ]]; then
      _ds_limit_ok "systemd journal capped at $max_use"
    else
      _ds_limit_warn "systemd journal has no size cap (currently $(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]' | head -n 1))" \
        "sudo mkdir -p /etc/systemd/journald.conf.d" \
        "printf '[Journal]\\nSystemMaxUse=500M\\n' | sudo tee /etc/systemd/journald.conf.d/size.conf" \
        "sudo systemctl restart systemd-journald"
    fi
  fi

  # pacman package cache
  if command -v pacman >/dev/null 2>&1; then
    if systemctl is-enabled paccache.timer >/dev/null 2>&1 ||
       grep -rqs paccache /etc/pacman.d/hooks /usr/share/libalpm/hooks; then
      _ds_limit_ok "pacman cache is pruned automatically (paccache)"
    elif command -v paccache >/dev/null 2>&1; then
      _ds_limit_warn "pacman cache is never pruned ($(_ds_fmt_kb "$(_ds_dir_kb /var/cache/pacman/pkg)"))" \
        "sudo systemctl enable --now paccache.timer"
    else
      _ds_limit_warn "pacman cache is never pruned ($(_ds_fmt_kb "$(_ds_dir_kb /var/cache/pacman/pkg)"))" \
        "sudo pacman -S pacman-contrib && sudo systemctl enable --now paccache.timer"
    fi
  fi

  # snap revisions (reading refresh.retain needs root, so infer from what's kept)
  if command -v snap >/dev/null 2>&1; then
    local max_revs
    max_revs=$(snap list --all 2>/dev/null | awk 'NR > 1 { c[$1]++ } END { m = 0; for (k in c) if (c[k] > m) m = c[k]; print m }')
    if [[ "${max_revs:-0}" -le 2 ]]; then
      _ds_limit_ok "snap keeps at most ${max_revs:-0} revisions per snap"
    else
      _ds_limit_warn "snap keeps up to $max_revs revisions per snap" \
        "sudo snap set system refresh.retain=2"
    fi
  fi

  # Docker build cache garbage collection
  if command -v docker >/dev/null 2>&1; then
    local cfg="/etc/docker/daemon.json"
    [[ "$(_ds_os)" == "mac" ]] && cfg="$HOME/.docker/daemon.json"
    if grep -qs '"gc"' "$cfg"; then
      _ds_limit_ok "Docker build cache GC is configured ($cfg)"
    else
      _ds_limit_warn "Docker build cache grows without limit" \
        "Add to $cfg:  \"builder\": { \"gc\": { \"enabled\": true, \"defaultKeepStorage\": \"10GB\" } }" \
        "Then restart the Docker daemon"
    fi
  fi

  unset -f _ds_limit_ok _ds_limit_warn

  echo ""
  if [[ $missing -eq 0 ]]; then
    printf "%sAll detected caches are capped.%s\n\n" "$DS_GREEN" "$DS_RESET"
  else
    printf "%s%d limit(s) missing.%s The commands above are suggestions — nothing was changed.\n\n" \
      "$DS_BOLD$DS_YELLOW" "$missing" "$DS_RESET"
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
# Cleanup Category Registry
#   id | kind (regen = rebuilt on demand, state = holds settings/packages)
#      | priv (user, sudo) | os (any, linux, mac) | label
# Each id has a `_ds_probe_<id>` (prints reclaimable KB) and a `_ds_clean_<id>`.
# sudo ids also have a `_ds_hint_<id>` (prints the command they would run).
# ------------------------------------------------------------------------------
_DS_CATEGORIES='docker|regen|user|any|Docker unused images, stopped containers & build cache
npm|regen|user|any|npm cache (~/.npm)
pnpm|regen|user|any|pnpm store
yarn|regen|user|any|Yarn cache
nuget|regen|user|any|.NET NuGet global cache (~/.nuget)
brew|regen|user|any|Homebrew downloads & stale formulae
playwright|regen|user|any|Playwright browsers (re-downloaded on demand)
gobuild|regen|user|any|Go build cache
pip|regen|user|any|pip download cache
gradle|regen|user|any|Gradle caches (~/.gradle/caches)
maven|regen|user|any|Maven repository (~/.m2/repository)
xcode|regen|user|mac|Xcode DerivedData
trash|regen|user|any|User Trash
pacman|regen|sudo|linux|pacman package cache
snaprev|regen|sudo|linux|Disabled snap revisions
journal|regen|sudo|linux|systemd journal (vacuum to 500M)
jetbrains|state|user|any|Old JetBrains IDE versions (settings, plugins, caches)
nvm|state|user|any|Old nvm Node.js versions (global npm packages)'

# --- Location helpers ---------------------------------------------------------
_ds_brew_cache_dir() {
  local d
  if command -v brew >/dev/null 2>&1; then
    d=$(brew --cache 2>/dev/null)
  fi
  # Brew might be installed but missing from PATH in this shell
  [[ -z "$d" && -d "$HOME/Library/Caches/Homebrew" ]] && d="$HOME/Library/Caches/Homebrew"
  [[ -z "$d" && -d "$HOME/.cache/Homebrew" ]] && d="$HOME/.cache/Homebrew"
  echo "$d"
}

_ds_go_cache_dir() {
  local d=""
  command -v go >/dev/null 2>&1 && d=$(go env GOCACHE 2>/dev/null)
  [[ -z "$d" && -d "$HOME/Library/Caches/go-build" ]] && d="$HOME/Library/Caches/go-build"
  [[ -z "$d" ]] && d="$HOME/.cache/go-build"
  echo "$d"
}

# "name rev" per disabled snap revision
_ds_snap_disabled() {
  command -v snap >/dev/null 2>&1 || return 0
  snap list --all 2>/dev/null | awk 'NR > 1 && $NF ~ /(^|,)disabled(,|$)/ { print $1, $3 }'
}

# Paths of JetBrains version dirs older than the newest one per product
# (matches e.g. WebStorm2025.2; Toolbox and other non-versioned dirs are kept)
_ds_jetbrains_stale() {
  local base
  for base in "$HOME/.local/share/JetBrains" "$HOME/.cache/JetBrains" \
              "$HOME/Library/Application Support/JetBrains" "$HOME/Library/Caches/JetBrains"; do
    [[ -d "$base" ]] && find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
  done | awk '
    {
      name = $0; sub(/.*\//, "", name)
      if (!match(name, /[0-9][0-9][0-9][0-9]\.[0-9]+$/)) next
      product = substr(name, 1, RSTART - 1)
      if (product !~ /^[A-Za-z]+$/) next
      split(substr(name, RSTART), v, ".")
      key = v[1] * 1000 + v[2]
      paths[NR] = $0; prod[NR] = product; ver[NR] = key
      if (key > newest[product]) newest[product] = key
    }
    END { for (i in paths) if (ver[i] < newest[prod[i]]) print paths[i] }'
}

# Paths of nvm Node versions that are safe to offer for removal. Keeps:
# the active version, the newest of each major, and any version referenced by a
# systemd unit (e.g. a service PATH pointing into ~/.nvm).
_ds_nvm_stale() {
  local root="${NVM_DIR:-$HOME/.nvm}/versions/node"
  [[ -d "$root" ]] || return 0
  local keep=" "
  keep+="$(node -v 2>/dev/null) "
  keep+="$(grep -rhos '\.nvm/versions/node/v[0-9][0-9.]*' /etc/systemd/system "$HOME/.config/systemd/user" 2>/dev/null |
    sed 's|.*/||' | sort -u | tr '\n' ' ')"
  find "$root" -mindepth 1 -maxdepth 1 -type d -name 'v*' 2>/dev/null | awk -v keep="$keep" '
    {
      v = $0; sub(/.*\//, "", v)
      split(substr(v, 2), p, ".")
      key = p[1] * 1000000 + p[2] * 1000 + p[3]
      paths[NR] = $0; vers[NR] = v; major[NR] = p[1]; k[NR] = key
      if (key > newest[p[1]]) newest[p[1]] = key
    }
    END {
      for (i in paths)
        if (k[i] < newest[major[i]] && index(keep, " " vers[i] " ") == 0) print paths[i]
    }'
}

# --- Probes (print reclaimable KB) --------------------------------------------
_ds_probe_docker() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 || { echo 0; return; }
  local kb=0 type size
  while IFS=$'\t' read -r type size; do
    case "$type" in
      Images|Containers|"Build Cache") kb=$((kb + $(_ds_parse_size "$size" 1000))) ;;
    esac
  done < <(docker system df --format '{{.Type}}\t{{.Reclaimable}}' 2>/dev/null)
  echo "$kb"
}
_ds_probe_npm()        { _ds_dir_kb "$HOME/.npm"; }
_ds_probe_pnpm()       { command -v pnpm >/dev/null 2>&1 && _ds_dir_kb "$(pnpm store path 2>/dev/null)" || echo 0; }
_ds_probe_yarn()       { _ds_dir_kb "$HOME/Library/Caches/Yarn" "$HOME/.cache/yarn"; }
_ds_probe_nuget()      { _ds_dir_kb "$HOME/.nuget/packages"; }
_ds_probe_brew()       { _ds_dir_kb "$(_ds_brew_cache_dir)"; }
_ds_probe_playwright() { _ds_dir_kb "$HOME/.cache/ms-playwright" "$HOME/Library/Caches/ms-playwright"; }
_ds_probe_gobuild()    { _ds_dir_kb "$(_ds_go_cache_dir)"; }
_ds_probe_pip()        { _ds_dir_kb "$HOME/.cache/pip" "$HOME/Library/Caches/pip"; }
_ds_probe_gradle()     { _ds_dir_kb "$HOME/.gradle/caches"; }
_ds_probe_maven()      { _ds_dir_kb "$HOME/.m2/repository"; }
_ds_probe_xcode()      { _ds_dir_kb "$HOME/Library/Developer/Xcode/DerivedData"; }
_ds_probe_trash()      { _ds_dir_kb "$HOME/.Trash" "$HOME/.local/share/Trash"; }
_ds_probe_pacman()     { command -v pacman >/dev/null 2>&1 && _ds_dir_kb /var/cache/pacman/pkg || echo 0; }
_ds_probe_journal() {
  command -v journalctl >/dev/null 2>&1 || { echo 0; return; }
  local kb
  kb=$(_ds_dir_kb /var/log/journal /run/log/journal)
  # Vacuuming keeps 500M
  echo $(( kb > 512000 ? kb - 512000 : 0 ))
}
_ds_probe_snaprev() {
  local -a files=()
  local name rev
  while read -r name rev; do
    [[ -n "$name" ]] && files+=("/var/lib/snapd/snaps/${name}_${rev}.snap")
  done < <(_ds_snap_disabled)
  [[ ${#files[@]} -eq 0 ]] && { echo 0; return; }
  _ds_dir_kb "${files[@]}"
}
_ds_probe_jetbrains() {
  local -a dirs=()
  local d
  while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(_ds_jetbrains_stale)
  [[ ${#dirs[@]} -eq 0 ]] && { echo 0; return; }
  _ds_dir_kb "${dirs[@]}"
}
_ds_probe_nvm() {
  local -a dirs=()
  local d
  while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(_ds_nvm_stale)
  [[ ${#dirs[@]} -eq 0 ]] && { echo 0; return; }
  _ds_dir_kb "${dirs[@]}"
}

# --- Sudo hints (printed instead of running when --sudo isn't given) ----------
_ds_hint_pacman() {
  if command -v paccache >/dev/null 2>&1; then
    echo "sudo paccache -rk2 && sudo paccache -ruk0"
  else
    echo "sudo pacman -Sc   (or install pacman-contrib for: sudo paccache -rk2)"
  fi
}
_ds_hint_snaprev() {
  echo "snap list --all | awk '\$NF ~ /disabled/ {print \$1, \$3}' | while read -r n r; do sudo snap remove \"\$n\" --revision=\"\$r\"; done"
}
_ds_hint_journal() { echo "sudo journalctl --vacuum-size=500M"; }

# --- Cleanup actions ----------------------------------------------------------
_ds_step() { printf "%s🧹 %s...%s\n" "$DS_BOLD$DS_BLUE" "$1" "$DS_RESET"; }
_ds_done() { printf "%s✔ %s%s\n\n" "$DS_GREEN" "$1" "$DS_RESET"; }

_ds_clean_docker() {
  _ds_step "Cleaning Docker build cache, stopped containers and unused images"
  docker builder prune -f
  docker container prune -f
  docker image prune -a -f
  _ds_done "Docker cleaned."
}

_ds_clean_npm() {
  _ds_step "Cleaning npm cache"
  npm cache clean --force 2>/dev/null || rm -rf "$HOME/.npm/_cacache"
  _ds_done "npm cache cleaned."
}

_ds_clean_pnpm() {
  _ds_step "Pruning pnpm store"
  pnpm store prune 2>/dev/null || true
  _ds_done "pnpm store pruned."
}

_ds_clean_yarn() {
  _ds_step "Cleaning Yarn cache"
  yarn cache clean --all 2>/dev/null || rm -rf "$HOME/Library/Caches/Yarn" "$HOME/.cache/yarn"
  _ds_done "Yarn cache cleaned."
}

_ds_clean_nuget() {
  _ds_step "Clearing .NET NuGet caches"
  if command -v dotnet >/dev/null 2>&1; then
    dotnet nuget locals all --clear
  else
    rm -rf "$HOME/.nuget/packages"
  fi
  _ds_done "NuGet cache cleared."
}

_ds_clean_brew() {
  _ds_step "Cleaning Homebrew downloads and cache"
  command -v brew >/dev/null 2>&1 && { brew cleanup --prune=all -s 2>/dev/null || true; }
  _ds_empty_dir "$(_ds_brew_cache_dir)"
  _ds_done "Homebrew cleaned."
}

_ds_clean_playwright() {
  _ds_step "Removing Playwright browsers"
  _ds_empty_dir "$HOME/.cache/ms-playwright"
  _ds_empty_dir "$HOME/Library/Caches/ms-playwright"
  _ds_done "Playwright browsers removed (run 'npx playwright install' to restore)."
}

_ds_clean_gobuild() {
  _ds_step "Cleaning Go build cache"
  if command -v go >/dev/null 2>&1; then
    go clean -cache
  else
    _ds_empty_dir "$(_ds_go_cache_dir)"
  fi
  _ds_done "Go build cache cleaned."
}

_ds_clean_pip() {
  _ds_step "Cleaning pip cache"
  _ds_empty_dir "$HOME/.cache/pip"
  _ds_empty_dir "$HOME/Library/Caches/pip"
  _ds_done "pip cache cleaned."
}

_ds_clean_gradle() {
  _ds_step "Cleaning Gradle caches"
  _ds_empty_dir "$HOME/.gradle/caches"
  _ds_done "Gradle caches cleaned."
}

_ds_clean_maven() {
  _ds_step "Cleaning Maven repository"
  _ds_empty_dir "$HOME/.m2/repository"
  _ds_done "Maven repository cleaned (dependencies re-download on next build)."
}

_ds_clean_xcode() {
  _ds_step "Removing Xcode DerivedData"
  _ds_empty_dir "$HOME/Library/Developer/Xcode/DerivedData"
  _ds_done "Xcode DerivedData removed."
}

_ds_clean_trash() {
  _ds_step "Emptying Trash"
  _ds_empty_dir "$HOME/.Trash"
  _ds_empty_dir "$HOME/.local/share/Trash"
  _ds_done "Trash emptied."
}

_ds_clean_pacman() {
  _ds_step "Pruning pacman package cache"
  if command -v paccache >/dev/null 2>&1; then
    sudo paccache -rk2 && sudo paccache -ruk0
  else
    sudo pacman -Sc --noconfirm
  fi
  _ds_done "pacman cache pruned."
}

_ds_clean_snaprev() {
  _ds_step "Removing disabled snap revisions"
  local name rev
  while read -r name rev; do
    [[ -n "$name" ]] && sudo snap remove "$name" --revision="$rev"
  done < <(_ds_snap_disabled)
  _ds_done "Disabled snap revisions removed."
}

_ds_clean_journal() {
  _ds_step "Vacuuming systemd journal to 500M"
  sudo journalctl --vacuum-size=500M
  _ds_done "Journal vacuumed."
}

_ds_clean_jetbrains() {
  _ds_step "Removing old JetBrains IDE version directories"
  local d
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    printf "   %s- %s%s\n" "$DS_DIM" "$d" "$DS_RESET"
    rm -rf "$d"
  done < <(_ds_jetbrains_stale)
  _ds_done "Old JetBrains versions removed."
}

_ds_clean_nvm() {
  _ds_step "Removing old nvm Node.js versions"
  local d v
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    v="${d##*/}"
    printf "   %s- %s%s\n" "$DS_DIM" "$v" "$DS_RESET"
    if typeset -f nvm >/dev/null 2>&1; then
      nvm uninstall "$v" >/dev/null
    else
      rm -rf "$d"
    fi
  done < <(_ds_nvm_stale)
  _ds_done "Old Node.js versions removed."
}

# ------------------------------------------------------------------------------
# Subcommand: clean — Interactive & Modular Disk Cleanup Engine
# ------------------------------------------------------------------------------
_diskspace_clean() {
  _ds_setup_colors

  local mode="interactive"
  local dry_run=0 use_sudo=0 assume_yes=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1 ;;
      --all)     mode="all" ;;
      --docker)  mode="docker" ;;
      --pkg)     mode="pkg" ;;
      --sudo)    use_sudo=1 ;;
      --yes|-y)  assume_yes=1 ;;
      --help|-h)
        printf "%sUsage: diskspace clean [options]%s\n\n" "$DS_BOLD" "$DS_RESET"
        echo "Options:"
        echo "  (none)      Interactive multi-selection menu (fzf if available, else menu)"
        echo "  --dry-run   Preview all reclaimable space without deleting anything"
        echo "  --all       Clean all regenerable caches with a single confirmation prompt"
        echo "  --docker    Clean Docker unused images, stopped containers & build cache only"
        echo "  --pkg       Clean npm, pnpm, yarn, and NuGet package caches"
        echo "  --sudo      Also run 🔒 items (asks for your password once, up front)"
        echo "  --yes, -y   Skip the --all confirmation prompt"
        echo ""
        echo "Markers:"
        echo "  🔒  needs sudo — without --sudo its command is printed instead of run"
        echo "  ⚠️   holds state (settings/packages) — only offered in the interactive menu"
        echo ""
        echo "Items smaller than DS_MIN_KB (default 10240 KB) are hidden."
        return 0
        ;;
      *)
        echo "Unknown option: $1 (run 'diskspace clean --help' for options)" >&2
        return 1
        ;;
    esac
    shift
  done

  printf "%s%sScanning reclaimable caches and disk hogs...%s\n" "$DS_DIM" "$DS_CYAN" "$DS_RESET"

  # Probe every applicable category → "kb::id::kind::priv::label" (kb first for sorting)
  local cur_os id kind priv os label kb
  cur_os=$(_ds_os)
  local -a probed=()
  while IFS='|' read -r id kind priv os label; do
    [[ -n "$id" ]] || continue
    [[ "$os" == "any" || "$os" == "$cur_os" ]] || continue
    kb=$("_ds_probe_$id" </dev/null)
    [[ "${kb:-0}" -ge "$DS_MIN_KB" ]] || continue
    probed+=("$kb::$id::$kind::$priv::$label")
  done <<< "$_DS_CATEGORIES"

  local -a items=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && items+=("$line")
  done < <(printf "%s\n" "${probed[@]}" | sort -t: -k1,1rn)

  # Split an item into _it_kb/_it_id/_it_kind/_it_priv/_it_label
  local _it_kb _it_id _it_kind _it_priv _it_label
  _ds_parse_item() {
    local r="$1"
    _it_kb="${r%%::*}";   r="${r#*::}"
    _it_id="${r%%::*}";   r="${r#*::}"
    _it_kind="${r%%::*}"; r="${r#*::}"
    _it_priv="${r%%::*}"; _it_label="${r#*::}"
  }

  # Display line: size, label and markers
  _ds_item_line() {
    _ds_parse_item "$1"
    local marks=""
    [[ "$_it_priv" == "sudo" ]] && marks+=" 🔒"
    [[ "$_it_kind" == "state" ]] && marks+=" ⚠️"
    printf "%8s  %s%s" "$(_ds_fmt_kb "$_it_kb")" "$_it_label" "$marks"
  }

  local entry
  if [[ "$dry_run" -eq 1 ]]; then
    printf "\n%s%s=== Dry-Run: Reclaimable Space Summary ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
    if [[ ${#items[@]} -eq 0 ]]; then
      echo "Nothing reclaimable found."
    else
      local kb_user=0 kb_sudo=0 kb_state=0
      for entry in "${items[@]}"; do
        printf "  %s\n" "$(_ds_item_line "$entry")"
        _ds_parse_item "$entry"
        if [[ "$_it_kind" == "state" ]]; then
          kb_state=$((kb_state + _it_kb))
        elif [[ "$_it_priv" == "sudo" ]]; then
          kb_sudo=$((kb_sudo + _it_kb))
        else
          kb_user=$((kb_user + _it_kb))
        fi
      done
      printf "  %s\n" "--------------------------------------------------------"
      # Padded columns stay ASCII-only: bash pads by bytes, zsh by characters
      printf "  %8s  %-20s %s\n" "$(_ds_fmt_kb $kb_user)" "Regenerable caches" "→ diskspace clean --all"
      [[ $kb_sudo -gt 0 ]]  && printf "  %8s  %-20s %s\n" "$(_ds_fmt_kb $kb_sudo)" "Needs sudo" "→ diskspace clean --all --sudo  🔒"
      [[ $kb_state -gt 0 ]] && printf "  %8s  %-20s %s\n" "$(_ds_fmt_kb $kb_state)" "Holds state" "→ diskspace clean (interactive)  ⚠️"
      printf "  %s%8s  %s%s\n" "$DS_BOLD" "$(_ds_fmt_kb $((kb_user + kb_sudo + kb_state)))" "Total reclaimable" "$DS_RESET"
    fi
    printf "\n%sNo files were deleted.%s To clean, run: %sdiskspace clean%s\n\n" \
      "$DS_DIM" "$DS_RESET" "$DS_BOLD" "$DS_RESET"
    return 0
  fi

  # Selected entries to clean, filled by the chosen mode below
  local -a selected=()

  case "$mode" in
    docker)
      if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
        echo "Docker is not currently running." >&2
        return 1
      fi
      selected=("0::docker::regen::user::Docker")
      ;;
    pkg)
      for entry in "${items[@]}"; do
        _ds_parse_item "$entry"
        [[ "$_it_id" =~ ^(npm|pnpm|yarn|nuget)$ ]] && selected+=("$entry")
      done
      ;;
    all)
      local kb_total=0
      for entry in "${items[@]}"; do
        _ds_parse_item "$entry"
        [[ "$_it_kind" == "regen" ]] || continue
        [[ "$_it_priv" == "user" || $use_sudo -eq 1 ]] || continue
        selected+=("$entry")
        kb_total=$((kb_total + _it_kb))
      done
      if [[ ${#selected[@]} -gt 0 && $assume_yes -eq 0 ]]; then
        printf "\n%sThe following will be cleaned (~%s):%s\n" "$DS_BOLD" "$(_ds_fmt_kb $kb_total)" "$DS_RESET"
        for entry in "${selected[@]}"; do printf "  %s\n" "$(_ds_item_line "$entry")"; done
        printf "\n%sProceed?%s (y/N): " "$DS_BOLD$DS_YELLOW" "$DS_RESET"
        local confirm
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
          echo "Cleanup aborted."
          return 0
        fi
      fi
      ;;
    interactive)
      if [[ ${#items[@]} -eq 0 ]]; then
        echo "Nothing reclaimable found."
        return 0
      fi
      if command -v fzf >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
        local picked idx
        picked=$(idx=1; for entry in "${items[@]}"; do
            printf "%s::%s\n" "$idx" "$(_ds_item_line "$entry")"; idx=$((idx + 1))
          done | fzf -m \
          --header="TAB/SPACE to select, ENTER to clean, ESC to cancel   🔒 needs --sudo   ⚠️  holds state" \
          --prompt="Clean > " \
          --delimiter="::" \
          --with-nth=2 \
          --bind="space:toggle" \
          --height=50% \
          --reverse)
        while IFS= read -r line; do
          [[ -n "$line" ]] || continue
          idx="${line%%::*}"
          # Portable 1-based lookup (bash arrays are 0-based, zsh 1-based)
          local n=1
          for entry in "${items[@]}"; do
            [[ $n -eq $idx ]] && selected+=("$entry")
            n=$((n + 1))
          done
        done <<< "$picked"
      else
        # Fallback numbered menu when fzf is missing or not interactive
        printf "\n%s%s=== Select Items to Clean ===%s\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
        local idx=1
        for entry in "${items[@]}"; do
          printf "  [%2d] %s\n" "$idx" "$(_ds_item_line "$entry")"
          idx=$((idx + 1))
        done
        printf "  [ a] All regenerable caches (excludes ⚠️ )\n"
        printf "  [ q] Cancel\n\n"
        printf "Enter choices separated by spaces (e.g. 1 2 3 or a): "
        local choices choice curr
        read -r choices

        # Split on spaces/commas via tr so it works identically in bash and zsh
        while IFS= read -r choice; do
          [[ "$choice" == "q" ]] && { selected=(); break; }
          curr=1
          for entry in "${items[@]}"; do
            _ds_parse_item "$entry"
            if [[ ( "$choice" == "a" && "$_it_kind" == "regen" ) || "$choice" == "$curr" ]]; then
              selected+=("$entry")
            fi
            curr=$((curr + 1))
          done
        done < <(printf "%s\n" "$choices" | tr -s ' ,' '\n\n')
      fi
      ;;
  esac

  if [[ ${#selected[@]} -eq 0 ]]; then
    echo "Nothing selected — cleanup cancelled."
    unset -f _ds_parse_item _ds_item_line
    return 0
  fi

  # Validate sudo once, up front, so no password prompt appears mid-run
  if [[ $use_sudo -eq 1 ]]; then
    for entry in "${selected[@]}"; do
      _ds_parse_item "$entry"
      if [[ "$_it_priv" == "sudo" ]]; then
        sudo -v || { echo "sudo authentication failed; 🔒 items will be skipped." >&2; use_sudo=0; }
        break
      fi
    done
  fi

  local used_before
  used_before=$(_ds_used_kb)

  echo ""
  # De-duplicate (e.g. "1 1" or "a 2") while preserving order
  local done_ids=" " hints=""
  for entry in "${selected[@]}"; do
    _ds_parse_item "$entry"
    [[ "$done_ids" == *" $_it_id "* ]] && continue
    done_ids+="$_it_id "
    if [[ "$_it_priv" == "sudo" && $use_sudo -ne 1 ]]; then
      hints+="   • $_it_label: $("_ds_hint_$_it_id")"$'\n'
      continue
    fi
    "_ds_clean_$_it_id"
  done

  if [[ -n "$hints" ]]; then
    printf "%s🔒 Skipped (needs sudo). Re-run with --sudo, or run manually:%s\n%s\n" \
      "$DS_BOLD$DS_YELLOW" "$DS_RESET" "$hints"
  fi

  local freed=$(( used_before - $(_ds_used_kb) ))
  [[ $freed -lt 0 ]] && freed=0
  printf "%sCleaning completed — freed %s.%s\n\n" "$DS_BOLD$DS_GREEN" "$(_ds_fmt_kb $freed)" "$DS_RESET"

  unset -f _ds_parse_item _ds_item_line
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
    limits)
      _diskspace_limits
      ;;
    help|--help|-h)
      if [[ "${2:-}" == "storage" ]]; then
        _ds_help_storage
        return 0
      fi
      _ds_setup_colors
      printf "%s%sdiskspace%s — Intelligent Disk Space Inspector & Cleaner\n\n" "$DS_BOLD" "$DS_CYAN" "$DS_RESET"
      printf "%sUsage:%s\n" "$DS_BOLD" "$DS_RESET"
      echo "  diskspace                     Show disk usage, capacity bars, and storage layout warnings"
      echo "  diskspace status              Explicit status overview (same as bare diskspace)"
      echo "  diskspace top [path] [n]      Show top [n] largest directories in [path] (default: \$HOME, 10)"
      echo "  diskspace limits              Check that journal/pacman/snap/Docker caches are capped"
      echo "  diskspace clean               Interactive multi-select cleanup menu"
      echo "  diskspace clean --dry-run     Size-sorted list of reclaimable space with totals"
      echo "  diskspace clean --all         Clean all regenerable caches (add --sudo, --yes as needed)"
      echo "  diskspace clean --docker      Clean Docker images, stopped containers and build cache only"
      echo "  diskspace clean --pkg         Clean npm, pnpm, yarn, and NuGet package caches"
      echo "  diskspace clean --help        All clean options and markers"
      echo "  diskspace help storage        How to move Docker/Ollama data to another disk"
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
