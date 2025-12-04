#!/usr/bin/env bash
# vmpkg - Very Minimal / Very Modular Package Manager
# Self-contained Linux user-space package manager.
#
# - No dependency on apt, dnf, pacman, yum, zypper, apk, xbps, emerge, etc.
# - Everything lives under: $HOME/.vmpkg (or $VMPKG_ROOT)
# - Packages are simple archives (tar.gz / tar / zip) downloaded from URLs
# - Extracted into:   $VMPKG_ROOT/pkgs/<name>-<version>
# - Binaries linked to $VMPKG_BIN (default: $HOME/.local/bin)
#
# Registry format (pipe-separated):
#   name|version|url|description
#
# LICENSE: MIT

set -euo pipefail

readonly VMPKG_VERSION="1.1.1"

###############################################################################
# ENV / FLAGS
###############################################################################

VMPKG_ASSUME_YES="${VMPKG_ASSUME_YES:-0}"
VMPKG_DRY_RUN="${VMPKG_DRY_RUN:-0}"
VMPKG_NO_COLOR="${VMPKG_NO_COLOR:-0}"
VMPKG_DEBUG="${VMPKG_DEBUG:-0}"
VMPKG_QUIET="${VMPKG_QUIET:-0}"
VMPKG_ARGS=()

###############################################################################
# COLORS & UI
###############################################################################

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

apply_color_mode() {
  if [[ "${VMPKG_NO_COLOR}" -eq 1 || -n "${NO_COLOR-}" ]]; then
    BOLD=''; DIM=''; GREEN=''; YELLOW=''; RED=''; BLUE=''; MAGENTA=''; CYAN=''; RESET=''
  fi
}

timestamp() {
  date +"%H:%M:%S"
}

log() {
  if [[ "${VMPKG_QUIET}" -eq 1 ]]; then return; fi
  printf "%b[%s]%b %bVMPKG%b %b✓%b %s\n" \
    "${DIM}" "$(timestamp)" "${RESET}" \
    "${BOLD}${CYAN}" "${RESET}" \
    "${GREEN}" "${RESET}" \
    "$*" >&2
}

log_success() {
  if [[ "${VMPKG_QUIET}" -eq 1 ]]; then return; fi
  printf "%b[%s]%b %bVMPKG%b %b✔ SUCCESS%b %s\n" \
    "${DIM}" "$(timestamp)" "${RESET}" \
    "${BOLD}${CYAN}" "${RESET}" \
    "${GREEN}" "${RESET}" \
    "$*" >&2
}

warn() {
  printf "%b[%s]%b %bVMPKG%b %b⚠ WARN%b %s\n" \
    "${DIM}" "$(timestamp)" "${RESET}" \
    "${BOLD}${CYAN}" "${RESET}" \
    "${YELLOW}" "${RESET}" \
    "$*" >&2
}

die() {
  printf "%b[%s]%b %bVMPKG%b %b✗ ERROR%b %s\n" \
    "${DIM}" "$(timestamp)" "${RESET}" \
    "${BOLD}${CYAN}" "${RESET}" \
    "${RED}" "${RESET}" \
    "$*" >&2
  exit 1
}

debug() {
  if [[ "${VMPKG_DEBUG}" -eq 1 ]]; then
    printf "%b[%s]%b %bVMPKG%b %bDBG%b %s\n" \
      "${DIM}" "$(timestamp)" "${RESET}" \
      "${BOLD}${CYAN}" "${RESET}" \
      "${MAGENTA}" "${RESET}" \
      "$*" >&2
  fi
}

ui_hr() {
  printf "%b%s%b\n" "${DIM}" "────────────────────────────────────────────────────────────" "${RESET}"
}

ui_title() {
  local msg="$1"
  ui_hr
  printf "%b▶ %s%b\n" "${BOLD}${BLUE}" "$msg" "${RESET}"
  ui_hr
}

ui_banner() {
  apply_color_mode
  printf "%b" "${BOLD}${MAGENTA}"
  cat <<'EOF'
 __     __  __  __  ____  _  __
 \ \   / / |  \/  ||  _ \| |/ /
  \ \ / /  | |\/| || |_) | ' / 
   \ V /   | |  | ||  __/| . \ 
    \_/    |_|  |_||_|   |_|\_\  Package Manager
EOF
  printf "%b\n" "${RESET}"
  printf "%bVersion %s%b\n" "${DIM}" "$VMPKG_VERSION" "${RESET}"
  ui_hr
}

###############################################################################
# SIGNAL & OS CHECK
###############################################################################

trap 'echo; die "Operation interrupted by user."' INT TERM

require_linux() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo "Unknown")"
  if [[ "$uname_s" != "Linux" ]]; then
    die "vmpkg supports Linux only. Detected: ${uname_s}"
  fi
}

###############################################################################
# CLI FLAGS
###############################################################################

parse_global_flags() {
  VMPKG_ARGS=()
  local arg
  for arg in "$@"; do
    case "$arg" in
      -y|--yes|--assume-yes) VMPKG_ASSUME_YES=1 ;;
      -n|--dry-run)          VMPKG_DRY_RUN=1 ;;
      --no-color)            VMPKG_NO_COLOR=1 ;;
      --debug)               VMPKG_DEBUG=1 ;;
      -q|--quiet)            VMPKG_QUIET=1 ;;
      *)                     VMPKG_ARGS+=("$arg") ;;
    esac
  done
}

vmpkg_confirm() {
  local msg="$1"
  if [[ "${VMPKG_ASSUME_YES}" -eq 1 ]]; then
    printf "vmpkg: %s [y/N]: y (auto)\n" "$msg"
    return 0
  fi

  local ans trimmed
  read -r -p "vmpkg: ${msg} [y/N]: " ans || true
  trimmed="${ans//[[:space:]]/}"

  case "$trimmed" in
    y|Y|yes|YES) return 0 ;;
    *) echo "vmpkg: Operation cancelled."; return 1 ;;
  esac
}

###############################################################################
# LAYOUT / PATHS
###############################################################################

VMPKG_ROOT="${VMPKG_ROOT:-"$HOME/.vmpkg"}"
VMPKG_REGISTRY="${VMPKG_REGISTRY:-"$VMPKG_ROOT/registry"}"
VMPKG_DB="$VMPKG_ROOT/db"
VMPKG_PKGS="$VMPKG_ROOT/pkgs"
VMPKG_CACHE="$VMPKG_ROOT/cache"
VMPKG_BIN="${VMPKG_BIN:-"$HOME/.local/bin"}"

ensure_layout() {
  mkdir -p "$VMPKG_ROOT" "$VMPKG_DB" "$VMPKG_PKGS" "$VMPKG_CACHE" "$VMPKG_BIN"
  if [[ ! -f "$VMPKG_REGISTRY" ]]; then
    cat >"$VMPKG_REGISTRY" <<EOF
# vmpkg registry
# Format (pipe-separated):
#   name|version|url|description
# Example:
#   bat|0.24.0|https://example.com/bat-0.24.0-x86_64.tar.gz|cat clone with wings
EOF
  fi
}

###############################################################################
# DOWNLOAD & ARCHIVE HANDLING
###############################################################################

choose_downloader() {
  if command -v curl >/dev/null 2>&1; then
    echo "curl"
  elif command -v wget >/dev/null 2>&1; then
    echo "wget"
  else
    die "Neither curl nor wget found. Install one of them to use vmpkg."
  fi
}

download_file() {
  local url="$1"
  local out="$2"

  if [[ -z "$url" ]]; then
    die "Empty URL for download."
  fi

  local dl
  dl="$(choose_downloader)"

  log "Downloading: ${url}"
  debug "Target file: ${out}"

  if [[ "${VMPKG_DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] Skipping actual download."
    return 0
  fi

  case "$dl" in
    curl)
      curl -L --fail --show-error --connect-timeout 15 --retry 3 -o "$out" "$url"
      ;;
    wget)
      wget --tries=3 --timeout=15 -O "$out" "$url"
      ;;
  esac
}

detect_archive_type() {
  local file="$1"
  case "$file" in
    *.tar.gz|*.tgz) echo "tar.gz" ;;
    *.tar)          echo "tar" ;;
    *.zip)          echo "zip" ;;
    *)              echo "unknown" ;;
  esac
}

extract_archive() {
  local archive="$1"
  local dest="$2"
  local type
  type="$(detect_archive_type "$archive")"

  [[ -d "$dest" ]] || mkdir -p "$dest"

  log "Extracting archive to: ${dest}"
  debug "Archive type detected: ${type}"

  case "$type" in
    tar.gz)
      command -v tar >/dev/null 2>&1 || die "tar is required to extract .tar.gz archives."
      tar -xzf "$archive" -C "$dest"
      ;;
    tar)
      command -v tar >/dev/null 2>&1 || die "tar is required to extract .tar archives."
      tar -xf "$archive" -C "$dest"
      ;;
    zip)
      command -v unzip >/dev/null 2>&1 || die "unzip is required to extract .zip archives."
      unzip -q "$archive" -d "$dest"
      ;;
    *)
      die "Unknown archive type for ${archive} (expected .tar.gz / .tar / .zip)."
      ;;
  esac
}

###############################################################################
# REGISTRY
###############################################################################

registry_find_line() {
  local name="$1"
  awk -F'|' -v n="$name" '
    NF >= 3 && $1 !~ /^#/ && $1 == n {print; exit}
  ' "$VMPKG_REGISTRY" 2>/dev/null || true
}

registry_register() {
  local name="$1" version="$2" url="$3" desc="$4"

  if [[ "$name" == *"|"* ]]; then
    die "Package name must not contain '|'."
  fi

  local tmp
  tmp="$(mktemp "${VMPKG_ROOT}/registry.XXXXXX")"

  if [[ -f "$VMPKG_REGISTRY" ]]; then
    awk -F'|' -v n="$name" '
      $1 == "" || $1 ~ /^#/ {print; next}
      $1 != n {print}
    ' "$VMPKG_REGISTRY" >"$tmp" || true
  fi

  printf '%s|%s|%s|%s\n' "$name" "$version" "$url" "$desc" >>"$tmp"
  mv "$tmp" "$VMPKG_REGISTRY"

  log "Registered package '${name}' version '${version}'."
}

###############################################################################
# MANIFESTS
###############################################################################

manifest_path_for() {
  local name="$1"
  printf "%s/%s.manifest\n" "$VMPKG_DB" "$name"
}

manifest_write() {
  local name="$1" version="$2" install_dir="$3" bin_links="$4"
  local mf
  mf="$(manifest_path_for "$name")"

  cat >"$mf" <<EOF
name=$name
version=$version
install_dir=$install_dir
bin_links=$bin_links
EOF
}

manifest_read_var() {
  local mf="$1" key="$2"
  if [[ ! -f "$mf" ]]; then
    return 1
  fi
  local line
  line="$(grep -E "^${key}=" "$mf" || true)"
  [[ -z "$line" ]] && return 1
  echo "${line#*=}"
}

###############################################################################
# CORE COMMANDS
###############################################################################

usage() {
  apply_color_mode
  ui_banner

  printf "%bUsage:%b %bvmpkg [options] <command> [args]%b\n\n" \
    "${BOLD}" "${RESET}" "${GREEN}" "${RESET}"

  printf "%bGlobal options:%b\n" "${BOLD}" "${RESET}"
  printf "  %b-y, --yes, --assume-yes%b    Assume yes for all prompts\n" "${YELLOW}" "${RESET}"
  printf "  %b-n, --dry-run%b             Preview only, no changes\n" "${YELLOW}" "${RESET}"
  printf "  %b--no-color%b                Disable colored output\n" "${YELLOW}" "${RESET}"
  printf "  %b--debug%b                   Verbose debug logging\n" "${YELLOW}" "${RESET}"
  printf "  %b-q, --quiet%b               Hide info logs\n\n" "${YELLOW}" "${RESET}"

  printf "%bCore commands:%b\n" "${BOLD}" "${RESET}"
  printf "  %binit%b                       Initialize vmpkg directories\n" "${GREEN}" "${RESET}"
  printf "  %bregister NAME VER URL [DESC]%b  Register package in local registry\n" "${GREEN}" "${RESET}"
  printf "  %binstall NAME%b               Install package from registry\n" "${GREEN}" "${RESET}"
  printf "  %breinstall NAME%b             Force reinstall package\n" "${GREEN}" "${RESET}"
  printf "  %bremove NAME%b                Remove installed package\n" "${GREEN}" "${RESET}"
  printf "  %blist%b                       List installed packages\n" "${GREEN}" "${RESET}"
  printf "  %bsearch PATTERN%b             Search registry entries\n" "${GREEN}" "${RESET}"
  printf "  %bshow NAME%b                  Show registry entry details\n" "${GREEN}" "${RESET}"
  printf "  %bclean%b                      Clean cache\n" "${GREEN}" "${RESET}"
  printf "  %bdoctor%b                     Diagnose environment\n\n" "${GREEN}" "${RESET}"

  printf "%bSystem helpers (optional eye-candy):%b\n" "${BOLD}" "${RESET}"
  printf "  %bsys-info%b                   Basic system info\n" "${GREEN}" "${RESET}"
  printf "  %bkernel%b                     Kernel version\n" "${GREEN}" "${RESET}"
  printf "  %bdisk%b                       Disk usage\n" "${GREEN}" "${RESET}"
  printf "  %bmem%b                        Memory usage\n" "${GREEN}" "${RESET}"
  printf "  %btop%b                        htop/top\n" "${GREEN}" "${RESET}"
  printf "  %bps%b                         Top processes by memory\n" "${GREEN}" "${RESET}"
  printf "  %bip%b                         Network info\n\n" "${GREEN}" "${RESET}"

  printf "%bEnvironment:%b\n" "${BOLD}" "${RESET}"
  printf "  %bVMPKG_ROOT%b                Root dir (default: ~/.vmpkg)\n" "${YELLOW}" "${RESET}"
  printf "  %bVMPKG_BIN%b                 Bin dir (default: ~/.local/bin)\n" "${YELLOW}" "${RESET}"
  printf "  %bVMPKG_ASSUME_YES=1%b        Assume yes for prompts\n" "${YELLOW}" "${RESET}"
  printf "  %bVMPKG_DRY_RUN=1%b           Global dry-run\n" "${YELLOW}" "${RESET}"
  printf "  %bVMPKG_NO_COLOR=1%b          Disable colors\n" "${YELLOW}" "${RESET}"
  printf "  %bVMPKG_DEBUG=1%b             Debug logs\n" "${YELLOW}" "${RESET}"
  printf "  %bVMPKG_QUIET=1%b             Hide info logs\n" "${YELLOW}" "${RESET}"
}

cmd_init() {
  ui_title "Initializing vmpkg"
  ensure_layout
  log_success "Initialized vmpkg at: ${VMPKG_ROOT}"
  log "Bin directory: ${VMPKG_BIN}"
  if [[ ":$PATH:" != *":$VMPKG_BIN:"* ]]; then
    echo
    printf "%bNOTE:%b Add this to your shell config (e.g. ~/.bashrc or ~/.zshrc):\n" "${YELLOW}" "${RESET}"
    printf "  export PATH=\"%s:\$PATH\"\n" "$VMPKG_BIN"
  fi
}

cmd_register() {
  ensure_layout
  if [[ $# -lt 3 ]]; then
    die "Usage: vmpkg register <name> <version> <url> [description...]"
  fi
  local name="$1"; shift
  local version="$1"; shift
  local url="$1"; shift
  local desc="${*:-no description}"

  ui_title "Registering package"
  printf "Name:        %s\n" "$name"
  printf "Version:     %s\n" "$version"
  printf "URL:         %s\n" "$url"
  printf "Description: %s\n" "$desc"
  echo

  if ! vmpkg_confirm "Add/Update this entry in registry?"; then
    return 1
  fi

  if [[ "${VMPKG_DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] Would register package in: ${VMPKG_REGISTRY}"
    return 0
  fi

  registry_register "$name" "$version" "$url" "$desc"
  log_success "Registry updated: ${VMPKG_REGISTRY}"
}

cmd_search() {
  ensure_layout
  if [[ $# -eq 0 ]]; then
    die "You must provide a search pattern."
  fi
  local pat="$1"
  ui_title "Search registry"
  echo "Registry file: ${VMPKG_REGISTRY}"
  echo
  if ! grep -i "$pat" "$VMPKG_REGISTRY" | grep -v '^[[:space:]]*#' ; then
    echo "No matches."
  fi
}

cmd_show() {
  ensure_layout
  if [[ $# -eq 0 ]]; then
    die "You must provide a package name."
  fi
  local name="$1"
  local line
  line="$(registry_find_line "$name")"
  if [[ -z "$line" ]]; then
    die "Package '${name}' not found in registry."
  fi

  ui_title "Package details"
  local n ver url desc
  IFS='|' read -r n ver url desc <<<"$line"
  printf "Name:        %s\n" "$n"
  printf "Version:     %s\n" "$ver"
  printf "URL:         %s\n" "$url"
  printf "Description: %s\n" "$desc"
}

link_binaries() {
  local pkg_root="$1"
  local name="$2"
  local bin_links=()

  local candidate_root="$pkg_root"

  if [[ ! -d "$candidate_root/bin" ]]; then
    local first_sub
    first_sub="$(find "$pkg_root" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
    if [[ -n "$first_sub" && -d "$first_sub/bin" ]]; then
      candidate_root="$first_sub"
    fi
  fi

  if [[ -d "$candidate_root/bin" ]]; then
    log "Linking executables from: ${candidate_root}/bin -> ${VMPKG_BIN}"
    local f base link_path
    for f in "$candidate_root/bin"/*; do
      [[ -f "$f" && -x "$f" ]] || continue
      base="$(basename "$f")"
      link_path="$VMPKG_BIN/$base"

      if [[ "${VMPKG_DRY_RUN}" -eq 1 ]]; then
        log "[DRY-RUN] Would link ${link_path} -> ${f}"
      else
        ln -sf "$f" "$link_path"
      fi
      bin_links+=("$link_path")
    done
  else
    warn "No bin/ directory found for package '${name}'. No symlinks created."
  fi

  local joined=""
  local sep=""
  local link
  for link in "${bin_links[@]}"; do
    joined+="${sep}${link}"
    sep=";"
  done
  echo "$joined"
}

cmd_install_internal() {
  local name="$1" reinstall_mode="${2:-0}"

  ensure_layout

  local line
  line="$(registry_find_line "$name")"
  if [[ -z "$line" ]]; then
    die "Package '${name}' not found in registry. Use 'vmpkg register' first."
  fi

  local n ver url desc
  IFS='|' read -r n ver url desc <<<"$line"

  local install_dir="$VMPKG_PKGS/${name}-${ver}"
  local archive="$VMPKG_CACHE/${name}-${ver}.pkg"

  ui_title "Install plan"
  printf "Name:        %s\n" "$name"
  printf "Version:     %s\n" "$ver"
  printf "URL:         %s\n" "$url"
  printf "Install dir: %s\n" "$install_dir"
  printf "Archive:     %s\n" "$archive"
  printf "Bin dir:     %s\n" "$VMPKG_BIN"
  echo

  if [[ -d "$install_dir" && "${reinstall_mode}" -eq 0 ]]; then
    warn "Package appears already installed at: ${install_dir}"
    warn "Use 'vmpkg reinstall ${name}' to force reinstall."
    return 0
  fi

  if ! vmpkg_confirm "Proceed with installation?"; then
    return 1
  fi

  download_file "$url" "$archive"

  if [[ "${VMPKG_DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] Skipping extract & link steps."
    return 0
  fi

  rm -rf "$install_dir"
  mkdir -p "$install_dir"

  extract_archive "$archive" "$install_dir"

  local bin_links
  bin_links="$(link_binaries "$install_dir" "$name")"

  manifest_write "$name" "$ver" "$install_dir" "$bin_links"

  log_success "Package '${name}' installed."
  echo
  ui_hr
  if [[ -n "$bin_links" ]]; then
    echo "Created symlinks:"
    IFS=';' read -ra arr <<<"$bin_links"
    local l
    for l in "${arr[@]}"; do
      [[ -z "$l" ]] && continue
      printf "  %s\n" "$l"
    done
  else
    echo "No executables linked (no bin/ directory found)."
  fi
  ui_hr
}

cmd_install() {
  if [[ $# -eq 0 ]]; then
    die "You must specify a package name to install."
  fi
  cmd_install_internal "$1" 0
}

cmd_reinstall() {
  if [[ $# -eq 0 ]]; then
    die "You must specify a package name to reinstall."
  fi
  cmd_install_internal "$1" 1
}

cmd_remove() {
  ensure_layout
  if [[ $# -eq 0 ]]; then
    die "You must specify a package name to remove."
  fi
  local name="$1"
  local mf
  mf="$(manifest_path_for "$name")"

  if [[ ! -f "$mf" ]]; then
    die "Package '${name}' is not installed (manifest not found: ${mf})."
  fi

  local install_dir bin_links
  install_dir="$(manifest_read_var "$mf" "install_dir" || true)"
  bin_links="$(manifest_read_var "$mf" "bin_links" || true)"

  ui_title "Removal plan"
  printf "Package:     %s\n" "$name"
  printf "Install dir: %s\n" "$install_dir"
  printf "Manifest:    %s\n" "$mf"
  printf "Bin links:   %s\n" "${bin_links:-<none>}"
  echo

  if ! vmpkg_confirm "Proceed with removal?"; then
    return 1
  fi

  if [[ "${VMPKG_DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] Would remove install dir, manifest, and symlinks."
    return 0
  fi

  if [[ -n "$bin_links" ]]; then
    IFS=';' read -ra arr <<<"$bin_links"
    local l
    for l in "${arr[@]}"; do
      [[ -z "$l" ]] && continue
      if [[ -L "$l" || -f "$l" ]]; then
        log "Removing link: ${l}"
        rm -f "$l"
      fi
    done
  fi

  if [[ -n "$install_dir" && -d "$install_dir" ]]; then
    log "Removing directory: ${install_dir}"
    rm -rf "$install_dir"
  fi

  log "Removing manifest: ${mf}"
  rm -f "$mf"

  log_success "Package '${name}' removed."
}

cmd_list() {
  ensure_layout
  ui_title "Installed packages"
  local mf
  local any=0
  for mf in "$VMPKG_DB"/*.manifest 2>/dev/null; do
    [[ -f "$mf" ]] || continue
    any=1
    local name ver
    name="$(manifest_read_var "$mf" "name" || echo "?")"
    ver="$(manifest_read_var "$mf" "version" || echo "?")"
    printf "  %-24s %s\n" "$name" "$ver"
  done
  if [[ "$any" -eq 0 ]]; then
    echo "  (none)"
  fi
}

cmd_clean() {
  ensure_layout
  ui_title "Clean cache"
  echo "Cache directory: ${VMPKG_CACHE}"
  echo
  if ! vmpkg_confirm "Remove all cached package archives?"; then
    return 1
  fi
  if [[ "${VMPKG_DRY_RUN}" -eq 1 ]]; then
    log "[DRY-RUN] Would remove cache files under ${VMPKG_CACHE}"
    return 0
  fi
  rm -rf "$VMPKG_CACHE"
  mkdir -p "$VMPKG_CACHE"
  log_success "Cache cleaned."
}

cmd_doctor() {
  ensure_layout
  ui_title "vmpkg doctor"

  local uname_s os_name=""
  uname_s="$(uname -s 2>/dev/null || echo "Unknown")"
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_name="${PRETTY_NAME:-$NAME}"
  fi

  echo "OS kernel:    ${uname_s}"
  echo "OS name:      ${os_name:-Unknown}"
  echo "Root:         ${VMPKG_ROOT}"
  echo "Registry:     ${VMPKG_REGISTRY}"
  echo "DB:           ${VMPKG_DB}"
  echo "Packages:     ${VMPKG_PKGS}"
  echo "Cache:        ${VMPKG_CACHE}"
  echo "Bin dir:      ${VMPKG_BIN}"
  ui_hr

  if command -v curl >/dev/null 2>&1; then
    log_success "curl detected."
  elif command -v wget >/dev/null 2>&1; then
    log_success "wget detected."
  else
    warn "Neither curl nor wget is installed. You cannot download packages."
  fi

  if command -v tar >/dev/null 2>&1; then
    log_success "tar detected."
  else
    warn "tar not found. tar-based archives will not work."
  fi

  if command -v unzip >/dev/null 2>&1; then
    log_success "unzip detected."
  else
    warn "unzip not found. zip archives will not work."
  fi

  if command -v free >/dev/null 2>&1; then
    log_success "free detected (memory info)."
  else
    warn "free not found. Memory info (cmd_mem/sys-info) may be limited."
  fi

  echo
  if [[ ":$PATH:" != *":$VMPKG_BIN:"* ]]; then
    warn "VMPKG_BIN is not in your PATH. Binaries may not be reachable by name."
    echo "    Bin dir: ${VMPKG_BIN}"
    echo "    Example fix:"
    echo "      export PATH=\"${VMPKG_BIN}:\$PATH\""
  else
    log_success "VMPKG_BIN is in PATH."
  fi
}

###############################################################################
# SYSTEM HELPERS (OPTIONAL)
###############################################################################

cmd_sys_info() {
  ui_title "System info"

  echo "=== uname ==="
  uname -a || true
  echo

  echo "=== CPU (first model line) ==="
  local cpu_line=""
  if [[ -r /proc/cpuinfo ]]; then
    cpu_line="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null || true)"
  fi
  if [[ -n "$cpu_line" ]]; then
    echo "$cpu_line"
  else
    echo "CPU info unavailable"
  fi
  echo

  echo "=== Memory ==="
  if command -v free >/dev/null 2>&1; then
    free -h
  else
    echo "free not available"
  fi
  echo

  echo "=== Disk (/) ==="
  if df -h / >/dev/null 2>&1; then
    df -h /
  else
    df -h || true
  fi
}

cmd_kernel() {
  ui_title "Kernel"
  uname -a || true
}

cmd_disk() {
  ui_title "Disk usage"
  df -h || true
}

cmd_mem() {
  ui_title "Memory usage"
  if command -v free >/dev/null 2>&1; then
    free -h
  else
    echo "free not available"
  fi
}

cmd_top() {
  ui_title "Top processes"
  if command -v htop >/dev/null 2>&1; then
    htop
  else
    top
  fi
}

cmd_ps() {
  ui_title "Top processes by memory"
  ps aux --sort=-%mem | head -n 15
}

cmd_ip() {
  ui_title "Network info"
  if command -v ip >/dev/null 2>&1; then
    ip addr
    echo
    ip route || true
  else
    echo "'ip' command not found. Install iproute2 or equivalent."
  fi
}

###############################################################################
# MAIN
###############################################################################

main() {
  require_linux

  case "${1-}" in
    -v|--version)
      echo "vmpkg ${VMPKG_VERSION}"
      exit 0
      ;;
  esac

  local cmd="${1:-}"
  shift || true

  parse_global_flags "$@"
  set -- "${VMPKG_ARGS[@]}"

  apply_color_mode

  case "${cmd}" in
    init)        cmd_init "$@" ;;
    register)    cmd_register "$@" ;;
    install)     cmd_install "$@" ;;
    reinstall)   cmd_reinstall "$@" ;;
    remove)      cmd_remove "$@" ;;
    list)        cmd_list "$@" ;;
    search)      cmd_search "$@" ;;
    show)        cmd_show "$@" ;;
    clean)       cmd_clean "$@" ;;
    doctor)      cmd_doctor "$@" ;;

    sys-info)    cmd_sys_info ;;
    kernel)      cmd_kernel ;;
    disk)        cmd_disk ;;
    mem)         cmd_mem ;;
    top)         cmd_top ;;
    ps)          cmd_ps ;;
    ip)          cmd_ip ;;

    ""|help|-h|--help)
      usage
      ;;
    *)
      die "Unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
