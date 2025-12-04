#!/usr/bin/env sh
# VMPKG Installer
# Installs vmpkg into /bin/vmpkg (or configured path) and ensures curl/wget is available.
# - Polite confirmation before doing anything (unless -y)
# - POSIX sh compatible
# - Uses system package manager *only* to install curl if missing

set -eu

VMPKG_URL="https://raw.githubusercontent.com/gpteamofficial/vmpkg/main/vmpkg"
VMPKG_DEST="/bin/vmpkg"

PKG_MGR=""
PKG_FAMILY=""
AUTO_YES=0

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
  printf '  -y, --yes, --assume-yes   Run non-interactively (assume "yes" to prompts)\n'
  printf '  -h, --help                Show this help and exit\n'
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fail "This installer must be run as root. Try: sudo $0"
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

ask_confirmation() {
  # $1 = message, $2 = default (Y/N, optional, default N)
  msg=$1
  default=${2:-N}

  # non-interactive mode: always yes
  if [ "$AUTO_YES" -eq 1 ]; then
    log "AUTO_YES enabled; auto-confirming: $msg"
    return 0
  fi

  case "$default" in
    Y|y)
      prompt="[Y/n]"
      def="Y"
      ;;
    *)
      prompt="[y/N]"
      def="N"
      ;;
  esac

  printf '%s[vmpkg-installer][PROMPT]%s %s %s ' "$C_WARN" "$C_RESET" "$msg" "$prompt" >&2
  if ! read -r ans </dev/tty; then
    return 1
  fi

  if [ -z "$ans" ]; then
    ans="$def"
  fi

  case "$ans" in
    Y|y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_curl_if_needed() {
  if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    return 0
  fi

  detect_pkg_mgr

  if [ -z "$PKG_MGR" ]; then
    fail "No supported package manager found to install curl (pacman/apt/dnf/yum/zypper/apk). Install curl or wget manually and rerun."
  fi

  log "Neither curl nor wget found. Installing curl using ${PKG_MGR}..."

  case "$PKG_FAMILY" in
    debian)
      "$PKG_MGR" update -y 2>/dev/null || "$PKG_MGR" update || true
      "$PKG_MGR" install -y curl
      ;;
    arch)
      pacman -Sy --noconfirm curl
      ;;
    redhat)
      "$PKG_MGR" install -y curl
      ;;
    suse)
      zypper refresh || true
      zypper install -y curl
      ;;
    alpine)
      apk update || true
      apk add curl
      ;;
    *)
      fail "Unsupported package manager family '${PKG_FAMILY}' for installing curl."
      ;;
  esac

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    fail "Failed to install curl. Please install curl or wget manually, then rerun."
  fi

  ok "curl (or wget) is now available."
}

download_vmpkg() {
  tmpfile="$(mktemp /tmp/vmpkg.XXXXXX.sh)"

  if command -v curl >/dev/null 2>&1; then
    log "Downloading VMPKG using curl..."
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
    fail "Neither curl nor wget available after installation step. Aborting."
  fi

  if [ ! -s "$tmpfile" ]; then
    rm -f "$tmpfile"
    fail "Downloaded file is empty. Check network or VMPKG_URL."
  fi

  ok "VMPKG script downloaded to temporary file."
  printf '%s\n' "$tmpfile"
}

install_vmpkg() {
  src=$1

  log "Installing VMPKG to ${VMPKG_DEST} ..."
  mkdir -p "$(dirname "$VMPKG_DEST")"

  mv "$src" "$VMPKG_DEST"
  chmod 0755 "$VMPKG_DEST"

  ok "VMPKG installed successfully at: ${VMPKG_DEST}"
}

print_summary() {
  printf '\n%sVMPKG installation completed.%s\n\n' "$C_OK" "$C_RESET"
  printf 'Binary location:\n  %s\n\n' "$VMPKG_DEST"
  printf 'Basic usage:\n'
  printf '  vmpkg init\n'
  printf '  vmpkg register <name> <version> <url> [description...]\n'
  printf '  vmpkg install <name>\n'
  printf '  vmpkg list\n'
  printf '  vmpkg show <name>\n\n'
  printf 'VMPKG is a self-contained user-space package manager for Linux.\n'
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -y|--yes|--assume-yes)
        AUTO_YES=1
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

  log "Welcome to the VMPKG installer."

  log "Planned actions:"
  log "  - Ensure curl or wget is installed."
  log "  - Download VMPKG from: $VMPKG_URL"
  log "  - Install VMPKG to:   $VMPKG_DEST"

  if ! ask_confirmation "Do you want to continue with these actions?" "N"; then
    warn "Installation aborted by user; nothing was changed."
    exit 0
  fi

  require_root
  install_curl_if_needed

  tmpfile="$(download_vmpkg)"
  install_vmpkg "$tmpfile"
  print_summary
}

main "$@"
