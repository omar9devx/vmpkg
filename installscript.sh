#!/usr/bin/env sh
# VMPKG Installer - Omar9DevX
# Installs vmpkg into ~/.local/bin/vmpkg (or /usr/local/bin/vmpkg)
# - Seamless user-space install without sudo
# - Frictionless execution for curl ... | bash and bash <(curl ...)
# - POSIX sh compatible

set -eu

VMPKG_URL="https://raw.githubusercontent.com/omar9devx/vmpkg/main/vmpkg"
VMPKG_DEST="${VMPKG_DEST:-}"

PKG_MGR=""
PKG_FAMILY=""

# --------------- colors (TTY-safe) ---------------

if [ -t 2 ] && [ "${NO_COLOR:-0}" = "0" ]; then
  C_RESET="$(printf '\033[0m')"
  C_INFO="$(printf '\033[1;34m')"  # blue
  C_WARN="$(printf '\033[1;33m')"  # yellow
  C_ERR="$(printf '\033[1;31m')"   # red
  C_OK="$(printf '\033[1;32m')"    # green
else
  C_RESET=''
  C_INFO=''
  C_WARN=''
  C_ERR=''
  C_OK=''
fi

# --------------- helpers ---------------

log() {
  printf '%s[vmpkg-installer]%s %s\n' "$C_INFO" "$C_RESET" "$*" >&2
}

warn() {
  printf '%s[vmpkg-installer][WARN]%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2
}

ok() {
  printf '%s[vmpkg-installer][OK]%s %s\n' "$C_OK" "$C_RESET" "$*" >&2
}

fail() {
  printf '%s[vmpkg-installer][ERROR]%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2
  exit 1
}

usage() {
  printf 'Usage: %s [OPTIONS]\n' "$0"
  printf '\nOptions:\n'
  printf '  --dest PATH               Custom installation binary path\n'
  printf '  -y, --yes, --assume-yes   Non-interactive mode (default)\n'
  printf '  -h, --help                Show this help and exit\n'
}

detect_dest() {
  if [ -z "${VMPKG_DEST:-}" ]; then
    if [ "$(id -u)" -eq 0 ]; then
      VMPKG_DEST="/usr/local/bin/vmpkg"
    elif [ -w "/usr/local/bin" ]; then
      VMPKG_DEST="/usr/local/bin/vmpkg"
    else
      VMPKG_DEST="$HOME/.local/bin/vmpkg"
      mkdir -p "$HOME/.local/bin"
    fi
  fi
}

detect_pkg_mgr() {
  if command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
    PKG_FAMILY="arch"
  elif command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt-get"
    PKG_FAMILY="debian"
  elif command -v apt >/dev/null 2>&1; then
    PKG_MGR="apt"
    PKG_FAMILY="debian"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
    PKG_FAMILY="redhat"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MGR="yum"
    PKG_FAMILY="redhat"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MGR="zypper"
    PKG_FAMILY="suse"
  elif command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"
    PKG_FAMILY="alpine"
  else
    PKG_MGR=""
    PKG_FAMILY=""
  fi
}

install_curl_if_needed() {
  if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    return 0
  fi

  detect_pkg_mgr

  if [ -z "$PKG_MGR" ]; then
    fail "Neither curl nor wget is found, and no supported package manager detected."
  fi

  log "Neither curl nor wget found. Installing curl using ${PKG_MGR}..."
  SUDO=""
  [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

  case "$PKG_FAMILY" in
    debian)
      $SUDO "$PKG_MGR" update -y 2>/dev/null || true
      $SUDO "$PKG_MGR" install -y curl
      ;;
    arch)
      $SUDO pacman -Sy --noconfirm curl
      ;;
    redhat)
      $SUDO "$PKG_MGR" install -y curl
      ;;
    suse)
      $SUDO zypper refresh || true
      $SUDO zypper install -y curl
      ;;
    alpine)
      $SUDO apk update || true
      $SUDO apk add --no-cache curl
      ;;
    *)
      fail "Unsupported package manager family '${PKG_FAMILY}' for installing curl."
      ;;
  esac

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    fail "Failed to install curl. Please install curl or wget manually, then rerun."
  fi

  ok "curl is now available."
}

download_vmpkg() {
  tmpfile="$(mktemp /tmp/vmpkg.XXXXXX.sh)"

  if command -v curl >/dev/null 2>&1; then
    log "Downloading VMPKG..."
    if ! curl -fsSL "$VMPKG_URL" -o "$tmpfile"; then
      rm -f "$tmpfile"
      fail "Failed to download VMPKG (curl)."
    fi
  elif command -v wget >/dev/null 2>&1; then
    log "Downloading VMPKG using wget..."
    if ! wget -qO "$tmpfile" "$VMPKG_URL"; then
      rm -f "$tmpfile"
      fail "Failed to download VMPKG (wget)."
    fi
  else
    rm -f "$tmpfile"
    fail "Neither curl nor wget available. Aborting."
  fi

  if [ ! -s "$tmpfile" ]; then
    rm -f "$tmpfile"
    fail "Downloaded file is empty. Check network or VMPKG_URL."
  fi

  ok "Downloaded."
  printf '%s\n' "$tmpfile"
}

install_vmpkg() {
  src=$1
  dest_dir="$(dirname "$VMPKG_DEST")"

  log "Installing VMPKG to ${VMPKG_DEST} ..."
  if [ -w "$dest_dir" ] || [ "$(id -u)" -eq 0 ]; then
    mkdir -p "$dest_dir"
    mv -f "$src" "$VMPKG_DEST"
    chmod 0755 "$VMPKG_DEST"
  elif command -v sudo >/dev/null 2>&1; then
    if sudo mkdir -p "$dest_dir" 2>/dev/null && sudo mv -f "$src" "$VMPKG_DEST" 2>/dev/null; then
      sudo chmod 0755 "$VMPKG_DEST"
    else
      warn "Permission denied for $VMPKG_DEST; falling back to $HOME/.local/bin/vmpkg..."
      VMPKG_DEST="$HOME/.local/bin/vmpkg"
      mkdir -p "$HOME/.local/bin"
      mv -f "$src" "$VMPKG_DEST"
      chmod 0755 "$VMPKG_DEST"
    fi
  else
    warn "Installing to user-space at $HOME/.local/bin/vmpkg..."
    VMPKG_DEST="$HOME/.local/bin/vmpkg"
    mkdir -p "$HOME/.local/bin"
    mv -f "$src" "$VMPKG_DEST"
    chmod 0755 "$VMPKG_DEST"
  fi

  ok "VMPKG installed successfully at: ${VMPKG_DEST}"
}

print_summary() {
  printf '\n%s==================================================%s\n' "$C_OK" "$C_RESET"
  printf '%s     VMPKG 1.4.0 Installation Complete!          %s\n' "$C_OK" "$C_RESET"
  printf '%s==================================================%s\n\n' "$C_OK" "$C_RESET"
  printf 'Binary location: %s\n' "$VMPKG_DEST"
  case ":$PATH:" in
    *":$(dirname "$VMPKG_DEST"):*") ;;
    *) warn "$(dirname "$VMPKG_DEST") is not in your PATH. Add it to ~/.bashrc or ~/.zshrc:\n  export PATH=\"$(dirname "$VMPKG_DEST"):\$PATH\"" ;;
  esac
  printf '\nBasic commands:\n'
  printf '  vmpkg init\n'
  printf '  vmpkg register <name> <version> <url> [desc] [sha256]\n'
  printf '  vmpkg install <name>\n'
  printf '  vmpkg upgrade [name]\n'
  printf '  vmpkg which <command>\n'
  printf '  vmpkg list\n'
  printf '  vmpkg show <name>\n\n'
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dest)
        shift
        [ "$#" -gt 0 ] && VMPKG_DEST="$1" || fail "--dest requires a path"
        ;;
      -y|--yes|--assume-yes)
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        warn "Unknown option: $1"
        ;;
    esac
    shift
  done
}

# --------------- main ---------------

main() {
  parse_args "$@"
  detect_pkg_mgr
  detect_dest

  log "Starting VMPKG installation..."
  log "Target destination: $VMPKG_DEST"

  install_curl_if_needed
  tmpfile="$(download_vmpkg)"
  install_vmpkg "$tmpfile"
  print_summary
}

main "$@"
