#!/usr/bin/env bash
#
# update-antigravity.sh — download & update Google Antigravity to the latest release.
#
# Downloads the official tarball straight from Google's CDN and installs it
# user-local (under ~/.local, no sudo, no conflict with pacman-owned files).
#
# The "latest version + build id" is resolved from the actively-maintained AUR
# PKGBUILD, because Google's CDN has no stable "latest" alias — the download URL
# embeds an opaque build number that only the packagers keep current.
#
#   update-antigravity.sh            # update the Antigravity IDE (VS Code fork; what /ide talks to)
#   update-antigravity.sh --hub      # update the Antigravity 2.0 desktop/hub app instead
#   update-antigravity.sh --force    # reinstall even if already on the latest build
#   update-antigravity.sh --check    # only report installed-vs-latest, install nothing
#
set -euo pipefail

# ---------------------------------------------------------------- configuration
PRODUCT="ide"                                   # ide | hub
FORCE=0
CHECK_ONLY=0
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$DATA_HOME/applications"

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }

usage() { grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ------------------------------------------------------------------- parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --hub)          PRODUCT="hub" ;;
    --ide)          PRODUCT="ide" ;;
    --force|-f)     FORCE=1 ;;
    --check|-n)     CHECK_ONLY=1 ;;
    -h|--help)      usage ;;
    *)              die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

command -v curl >/dev/null || die "curl is required"
command -v tar  >/dev/null || die "tar is required"

# --------------------------------------------------------------- architecture
case "$(uname -m)" in
  x86_64)         ARCH_DIR="linux-x64" ;;
  aarch64|arm64)  ARCH_DIR="linux-arm" ;;
  *)              die "unsupported architecture: $(uname -m)" ;;
esac

# ----------------------------------------------------- product-specific naming
case "$PRODUCT" in
  ide)
    AUR_PKG="antigravity-ide"
    SLUG="antigravity-ide"
    PRETTY="Antigravity IDE"
    ;;
  hub)
    AUR_PKG="antigravity"
    SLUG="antigravity"
    PRETTY="Antigravity"
    ;;
esac

TARGET="$DATA_HOME/$SLUG"          # where the app tree lives
STAMP="$TARGET/.version"           # records the installed "<ver>-<build>"

# ------------------------------------- resolve latest version+build (AUR oracle)
info "Resolving latest $PRETTY version…"
PKGBUILD="$(curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$AUR_PKG")" \
  || die "could not fetch PKGBUILD for $AUR_PKG from the AUR"
VER="$(grep -oP '^pkgver=\K[0-9.]+' <<<"$PKGBUILD" | head -1)"
BUILD="$(grep -oP '^_build=\K[0-9]+' <<<"$PKGBUILD" | head -1)"
[ -n "$VER" ] && [ -n "$BUILD" ] || die "could not parse version/build from PKGBUILD"
LATEST="$VER-$BUILD"

# --------------------------------------------------------------- build the URL
if [ "$PRODUCT" = "ide" ]; then
  URL="https://dl.google.com/release2/j0qc3/antigravity/stable/${VER}-${BUILD}/${ARCH_DIR}/Antigravity%20IDE.tar.gz"
else
  URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/${VER}-${BUILD}/${ARCH_DIR}/Antigravity.tar.gz"
fi

INSTALLED="$( [ -f "$STAMP" ] && cat "$STAMP" || echo "(none)" )"
info "Installed: $INSTALLED   Latest: $LATEST   ($ARCH_DIR)"

if [ "$CHECK_ONLY" -eq 1 ]; then
  [ "$INSTALLED" = "$LATEST" ] && echo "up to date" || echo "update available: $LATEST"
  exit 0
fi

if [ "$INSTALLED" = "$LATEST" ] && [ "$FORCE" -eq 0 ]; then
  info "Already on the latest build — nothing to do (use --force to reinstall)."
  exit 0
fi

# --------------------------------------------------------------- download + verify
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
info "Downloading $PRETTY $LATEST…"
curl -fL --progress-bar -o "$TMP/pkg.tar.gz" "$URL" \
  || die "download failed: $URL"
gzip -t "$TMP/pkg.tar.gz" || die "downloaded file is not a valid gzip archive"

info "Extracting…"
tar -xzf "$TMP/pkg.tar.gz" -C "$TMP"
SRC="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -n "$SRC" ] && [ -d "$SRC" ] || die "unexpected archive layout"

# --------------------------------------------------------------- atomic install
info "Installing to $TARGET…"
mkdir -p "$DATA_HOME" "$BIN_DIR" "$APPS_DIR"
rm -rf "$TARGET.new" "$TARGET.old"
mv "$SRC" "$TARGET.new"
[ -d "$TARGET" ] && mv "$TARGET" "$TARGET.old"
mv "$TARGET.new" "$TARGET"
rm -rf "$TARGET.old"
printf '%s\n' "$LATEST" > "$STAMP"

# --------------------------------------------------------------- cli + desktop entry
# CLI launcher (behaves like `code`): prefer bin/<slug>, else the root binary.
if [ -x "$TARGET/bin/$SLUG" ]; then CLI="$TARGET/bin/$SLUG"
else CLI="$(find "$TARGET/bin" -maxdepth 1 -type f 2>/dev/null | head -1)"; fi
[ -n "${CLI:-}" ] && ln -sfn "$CLI" "$BIN_DIR/$SLUG"

# GUI binary (the Electron executable at the tree root).
GUI="$TARGET/$SLUG"; [ -x "$GUI" ] || GUI="${CLI:-$TARGET/$SLUG}"
ICON="$(find "$TARGET/resources/app/resources/linux" -name '*.png' 2>/dev/null | head -1)"
[ -n "${ICON:-}" ] || ICON="$SLUG"

cat > "$APPS_DIR/$SLUG.desktop" <<EOF
[Desktop Entry]
Name=$PRETTY
Comment=An agentic development platform from Google
GenericName=Text Editor
Exec=$GUI %F
Icon=$ICON
Type=Application
StartupNotify=true
StartupWMClass=$PRETTY
Categories=Development;IDE;
Keywords=antigravity;google;ide;editor;
EOF

command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

info "Done. $PRETTY $LATEST installed."
echo "   binary : $BIN_DIR/$SLUG"
echo "   launch : $SLUG    (or find \"$PRETTY\" in your app menu)"

# PATH sanity check
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) printf '\033[33mnote:\033[0m %s is not on your PATH — add it in ~/.zshrc:\n      export PATH="%s:$PATH"\n' "$BIN_DIR" "$BIN_DIR" ;;
esac
