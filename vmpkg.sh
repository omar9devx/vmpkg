#!/usr/bin/env bash
# vmpkg - Very Minimal / Very Modular Package Manager
# Self-contained Linux user-space package manager.
#
# LICENSE: MIT

set -euo pipefail

VMPKG_VERSION="1.2.0"

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

BOLD=$'\033[1m'
DIM=$'\033[2m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
RESET=$'\033[0m'


apply_color_mode() {
  if [[ "$VMPKG_NO_COLOR" -eq 1 || -n "${NO_COLOR-}" ]]; then
    BOLD=''; DIM=''; GREEN=''; YELLOW=''; RED=''; BLUE=''; MAGENTA=''; CYAN=''; RESET=''
  fi
}

timestamp() {
  date +"%H:%M:%S"
}

log() {
  if [[ "$VMPKG_QUIET" -eq 1 ]]; then return; fi
  printf "%s[%s]%s %sVMPKG%s %s✓%s %s\n" \
    "$DIM" "$(timestamp)" "$RESET" \
    "$BOLD$CYAN" "$RESET" \
    "$GREEN" "$RESET" \
    "$*" >&2
}

log_success() {
  if [[ "$VMPKG_QUIET" -eq 1 ]]; then return; fi
  printf "%s[%s]%s %sVMPKG%s %s✔ SUCCESS%s %s\n" \
    "$DIM" "$(timestamp)" "$RESET" \
    "$BOLD$CYAN" "$RESET" \
    "$GREEN" "$RESET" \
    "$*" >&2
}

warn() {
  printf "%s[%s]%s %sVMPKG%s %s⚠ WARN%s %s\n" \
    "$DIM" "$(timestamp)" "$RESET" \
    "$BOLD$CYAN" "$RESET" \
    "$YELLOW" "$RESET" \
    "$*" >&2
}

die() {
  printf "%s[%s]%s %sVMPKG%s %s✗ ERROR%s %s\n" \
    "$DIM" "$(timestamp)" "$RESET" \
    "$BOLD$CYAN" "$RESET" \
    "$RED" "$RESET" \
    "$*" >&2
  exit 1
}

debug() {
  if [[ "$VMPKG_DEBUG" -eq 1 ]]; then
    printf "%s[%s]%s %sVMPKG%s %sDBG%s %s\n" \
      "$DIM" "$(timestamp)" "$RESET" \
      "$BOLD$CYAN" "$RESET" \
      "$MAGENTA" "$RESET" \
      "$*" >&2
  fi
}

ui_hr() {
  printf "%s%s%s\n" "$DIM" "────────────────────────────────────────────────────────────" "$RESET"
}

ui_title() {
  local msg="$1"
  ui_hr
  printf "%s▶ %s%s\n" "$BOLD$BLUE" "$msg" "$RESET"
  ui_hr
}

ui_banner() {
  apply_color_mode
  printf "%s" "$BOLD$MAGENTA"
  cat <<'EOF'
 __     __  __  __  ____  _  __
 \ \   / / |  \/  ||  _ \| |/ /
  \ \ / /  | |\/| || |_) | ' / 
   \ V /   | |  | ||  __/| . \ 
    \_/    |_|  |_||_|   |_|\_\  Package Manager
EOF
  printf "%s\n" "$RESET"
  printf "%sVersion %s%s\n" "$DIM" "$VMPKG_VERSION" "$RESET"
  ui_hr
}

###############################################################################
# SIGNAL & OS CHECK
###############################################################################

trap 'echo; die "Operation interrupted by user."' INT TERM

require_linux() {
  local uname_s
  uname_s="$(uname -s || echo "Unknown")"
  if [[ "$uname_s" != "Linux" ]]; then
    die "vmpkg supports Linux only. Detected: $uname_s"
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
  if [[ "$VMPKG_ASSUME_YES" -eq 1 ]]; then
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
  if command -v curl >/dev/null; then
    echo "curl"
  elif command -v wget >/dev/null; then
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

  log "Downloading: $url"
  debug "Target file: $out"

  if [[ "$VMPKG_DRY_RUN" -eq 1 ]]; then
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

  log "Extracting archive to: $dest"
  debug "Archive type detected: $type"

  case "$type" in
    tar.gz)
      command -v tar >/dev/null || die "tar is required to extract .tar.gz archives."
      tar -xzf "$archive" -C "$dest"
      ;;
    tar)
      command -v tar >/dev/null || die "tar is required to extract .tar archives."
      tar -xf "$archive" -C "$dest"
      ;;
    zip)
      command -v unzip >/dev/null || die "unzip is required to extract .zip archives."
      unzip -q "$archive" -d "$dest"
      ;;
    *)
      die "Unknown archive type for $archive (expected .tar.gz / .tar / .zip)."
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
  ' "$VMPKG_REGISTRY" || true
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

  log "Registered package '$name' version '$version'."
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

  printf "%sUsage:%s %svmpkg [options] <command> [args]%s\n\n" \
    "$BOLD" "$RESET" "$GREEN" "$RESET"

  printf "%sGlobal options:%s\n" "$BOLD" "$RESET"
  printf "  %s-y, --yes, --assume-yes%s    Assume yes for all prompts\n" "$YELLOW" "$RESET"
  printf "  %s-n, --dry-run%s             Preview only, no changes\n" "$YELLOW" "$RESET"
  printf "  %s--no-color%s                Disable colored output\n" "$YELLOW" "$RESET"
  printf "  %s--debug%s                   Verbose debug logging\n" "$YELLOW" "$RESET"
  printf "  %s-q, --quiet%s               Hide info logs\n\n" "$YELLOW" "$RESET"

  printf "%sCore commands:%s\n" "$BOLD" "$RESET"
  printf "  %sinit%s                       Initialize vmpkg directories\n" "$GREEN" "$RESET"
  printf "  %sregister NAME VER URL [DESC]%s  Register package in local registry\n" "$GREEN" "$RESET"
  printf "  %sinstall NAME%s               Install package from registry\n" "$GREEN" "$RESET"
  printf "  %sreinstall NAME%s             Force reinstall package\n" "$GREEN" "$RESET"
  printf "  %sremove NAME%s                Remove installed package\n" "$GREEN" "$RESET"
  printf "  %slist%s                       List installed packages\n" "$GREEN" "$RESET"
  printf "  %ssearch PATTERN%s             Search registry entries\n" "$GREEN" "$RESET"
  printf "  %sshow NAME%s                  Show registry entry details\n" "$GREEN" "$RESET"
  printf "  %sclean%s                      Clean cache\n" "$GREEN" "$RESET"
  printf "  %sdoctor%s                     Diagnose environment\n\n" "$GREEN" "$RESET"

  printf "%sEnvironment:%s\n" "$BOLD" "$RESET"
  printf "  %sVMPKG_ROOT%s                Root dir (default: ~/.vmpkg)\n" "$YELLOW" "$RESET"
  printf "  %sVMPKG_BIN%s                 Bin dir (default: ~/.local/bin)\n" "$YELLOW" "$RESET"
  printf "  %sVMPKG_ASSUME_YES=1%s        Assume yes for prompts\n" "$YELLOW" "$RESET"
  printf "  %sVMPKG_DRY_RUN=1%s           Global dry-run\n" "$YELLOW" "$RESET"
  printf "  %sVMPKG_NO_COLOR=1%s          Disable colors\n" "$YELLOW" "$RESET"
  printf "  %sVMPKG_DEBUG=1%s             Debug logs\n" "$YELLOW" "$RESET"
  printf "  %sVMPKG_QUIET=1%s             Hide info logs\n" "$YELLOW" "$RESET"
}

cmd_init() {
  ui_title "Initializing vmpkg"
  ensure_layout
  log_success "Initialized vmpkg at: $VMPKG_ROOT"
  log "Bin directory: $VMPKG_BIN"
  if [[ ":$PATH:" != *":$VMPKG_BIN:"* ]]; then
    echo
    printf "%sNOTE:%s Add this to your shell config (e.g. ~/.bashrc or ~/.zshrc):\n" "$YELLOW" "$RESET"
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

  if [[ "$VMPKG_DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Would register package in: $VMPKG_REGISTRY"
    return 0
  fi

  registry_register "$name" "$version" "$url" "$desc"
  log_success "Registry updated: $VMPKG_REGISTRY"
}

cmd_search() {
  ensure_layout
  if [[ $# -eq 0 ]]; then
    die "You must provide a search pattern."
  fi
  local pat="$1"
  ui_title "Search registry"
  echo "Registry file: $VMPKG_REGISTRY"
  echo
  if ! grep -i "$pat" "$VMPKG_REGISTRY" | grep -v '^[[:space:]]*#'; then
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
    die "Package '$name' not found in registry."
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
    log "Linking executables from: $candidate_root/bin -> $VMPKG_BIN"
    local f base link_path
    for f in "$candidate_root/bin"/*; do
      [[ -f "$f" && -x "$f" ]] || continue
      base="$(basename "$f")"
      link_path="$VMPKG_BIN/$base"

      if [[ "$VMPKG_DRY_RUN" -eq 1 ]]; then
        log "[DRY-RUN] Would link $link_path -> $f"
      else
        ln -sf "$f" "$link_path"
      fi
      bin_links+=("$link_path")
    done
  else
    warn "No bin/ directory found for package '$name'. No symlinks created."
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
    die "Package '$name' not found in registry. Use 'vmpkg register' first."
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

  if [[ -d "$install_dir" && "$reinstall_mode" -eq 0 ]]; then
    warn "Package appears already installed at: $install_dir"
    warn "Use 'vmpkg reinstall $name' to force reinstall."
    return 0
  fi

  if ! vmpkg_confirm "Proceed with installation?"; then
    return 1
  fi

  download_file "$url" "$archive"

  if [[ "$VMPKG_DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Skipping extract & link steps."
    return 0
  fi

  rm -rf "$install_dir"
  mkdir -p "$install_dir"

  extract_archive "$archive" "$install_dir"

  local bin_links
  bin_links="$(link_binaries "$install_dir" "$name")"

  manifest_write "$name" "$ver" "$install_dir" "$bin_links"

  log_success "Package '$name' installed."
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
    die "Package '$name' is not installed (manifest not found: $mf)."
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

  if [[ "$VMPKG_DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Would remove install dir, manifest, and symlinks."
    return 0
  fi

  if [[ -n "$bin_links" ]]; then
    IFS=';' read -ra arr <<<"$bin_links"
    local l
    for l in "${arr[@]}"; do
      [[ -z "$l" ]] && continue
      if [[ -L "$l" || -f "$l" ]]; then
        log "Removing link: $l"
        rm -f "$l"
      fi
    done
  fi

  if [[ -n "$install_dir" && -d "$install_dir" ]]; then
    log "Removing directory: $install_dir"
    rm -rf "$install_dir"
  fi

  log "Removing manifest: $mf"
  rm -f "$mf"

  log_success "Package '$name' removed."
}

cmd_list() {
  ensure_layout
  ui_title "Installed packages"
  local mf
  local any=0
  shopt -s nullglob
  for mf in "$VMPKG_DB"/*.manifest; do
    [[ -f "$mf" ]] || continue
    any=1
    local name ver
    name="$(manifest_read_var "$mf" "name" || echo "?")"
    ver="$(manifest_read_var "$mf" "version" || echo "?")"
    printf "  %-24s %s\n" "$name" "$ver"
  done
  shopt -u nullglob
  if [[ "$any" -eq 0 ]]; then
    echo "  (none)"
  fi
}

cmd_clean() {
  ensure_layout
  ui_title "Clean cache"
  echo "Cache directory: $VMPKG_CACHE"
  echo
  if ! vmpkg_confirm "Remove all cached package archives?"; then
    return 1
  fi
  if [[ "$VMPKG_DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Would remove cache files under $VMPKG_CACHE"
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
  uname_s="$(uname -s || echo "Unknown")"
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_name="${PRETTY_NAME:-$NAME}"
  fi

  echo "OS kernel:    $uname_s"
  echo "OS name:      ${os_name:-Unknown}"
  echo "Root:         $VMPKG_ROOT"
  echo "Registry:     $VMPKG_REGISTRY"
  echo "DB:           $VMPKG_DB"
  echo "Packages:     $VMPKG_PKGS"
  echo "Cache:        $VMPKG_CACHE"
  echo "Bin dir:      $VMPKG_BIN"
  ui_hr

  if command -v curl >/dev/null; then
    log_success "curl detected."
  elif command -v wget >/dev/null; then
    log_success "wget detected."
  else
    warn "Neither curl nor wget is installed. You cannot download packages."
  fi

  if command -v tar >/dev/null; then
    log_success "tar detected."
  else
    warn "tar not found. tar-based archives will not work."
  fi

  if command -v unzip >/dev/null; then
    log_success "unzip detected."
  else
    warn "unzip not found. zip archives will not work."
  fi

  echo
  if [[ ":$PATH:" != *":$VMPKG_BIN:"* ]]; then
    warn "VMPKG_BIN is not in your PATH. Binaries may not be reachable by name."
    echo "    Bin dir: $VMPKG_BIN"
    echo "    Example fix:"
    echo "      export PATH=\"${VMPKG_BIN}:\$PATH\""
  else
    log_success "VMPKG_BIN is in PATH."
  fi
}

###############################################################################
# MAIN
###############################################################################

main() {
  require_linux

  case "${1-}" in
    -v|--version)
      echo "vmpkg $VMPKG_VERSION"
      exit 0
      ;;
  esac

  local cmd="${1:-}"
  shift || true

  parse_global_flags "$@"
  set -- "${VMPKG_ARGS[@]}"

  apply_color_mode

  case "$cmd" in
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
    ""|help|-h|--help)
      usage
      ;;
    *)
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
