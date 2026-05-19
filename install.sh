#!/usr/bin/env bash
set -euo pipefail

VILAB_RELEASE_REPO="${VILAB_RELEASE_REPO:-Ro-In-AI/VILab-public}"
VILAB_SERVER_INSTALL_URL="${VILAB_SERVER_INSTALL_URL:-https://raw.githubusercontent.com/orulink-ai/VILab-server/main/install.sh}"
VILAB_INSTALL_TARGET="${VILAB_INSTALL_TARGET:-auto}"

if [ -n "${NO_COLOR:-}" ] || [ "${TERM:-}" = "dumb" ] || [ ! -t 1 ]; then
  VILAB_COLOR=false
else
  VILAB_COLOR=true
fi

if [ "$VILAB_COLOR" = true ]; then
  GREEN="$(printf '\033[0;32m')"
  BLUE="$(printf '\033[0;34m')"
  YELLOW="$(printf '\033[0;33m')"
  BOLD="$(printf '\033[1m')"
  NC="$(printf '\033[0m')"
else
  GREEN=''
  BLUE=''
  YELLOW=''
  BOLD=''
  NC=''
fi

say() {
  printf '%s\n' "$*"
}

print_banner() {
  say ""
  say "${GREEN}${BOLD}VILab quick install${NC}"
  say "Desktop client + headless server"
  say ""
}

log_step() {
  say "${BLUE}=>${NC} $*"
}

log_success() {
  say "${GREEN}OK${NC} $*"
}

log_warn() {
  say "${YELLOW}Warning:${NC} $*" >&2
}

fail() {
  say "vilab install: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"
}

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

latest_asset_url() {
  local repo="$1"
  local pattern="$2"
  python3 - "$repo" "$pattern" <<'PY'
import json
import re
import sys
import urllib.request

repo = sys.argv[1]
pattern = re.compile(sys.argv[2], re.IGNORECASE)

with urllib.request.urlopen(f"https://api.github.com/repos/{repo}/releases/latest") as response:
    payload = json.load(response)

for asset in payload.get("assets", []):
    name = asset.get("name", "")
    if pattern.search(name):
        print(asset["browser_download_url"])
        sys.exit(0)

sys.exit(1)
PY
}

download_latest_asset() {
  local repo="$1"
  local pattern="$2"
  local output="$3"
  need curl
  need python3

  log_step "Reading latest release from $repo"
  local url
  url="$(latest_asset_url "$repo" "$pattern")" || fail "no release asset matches $pattern in $repo"

  log_step "Downloading $url"
  if [ -t 1 ]; then
    curl -fL --progress-bar "$url" -o "$output"
  else
    curl -fsSL "$url" -o "$output"
  fi
}

install_macos_desktop() {
  local tmp
  tmp="$(mktemp -d)"
  local dmg="$tmp/VILab.dmg"
  download_latest_asset "$VILAB_RELEASE_REPO" '\.dmg$' "$dmg"
  log_step "Opening DMG. Drag VILab into Applications."
  open "$dmg"
  log_success "Desktop installer is ready: $dmg"
}

install_linux_server() {
  need curl
  local local_installer
  local_installer="$(script_dir)/../VILab-server/install.sh"

  if [ -f "$local_installer" ]; then
    log_step "Delegating to local VILab-server installer"
    bash "$local_installer"
    return
  fi

  log_step "Delegating to VILab-server installer: $VILAB_SERVER_INSTALL_URL"
  curl -fsSL "$VILAB_SERVER_INSTALL_URL" | bash
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

main() {
  local os
  os="$(uname -s)"
  print_banner

  case "$VILAB_INSTALL_TARGET" in
    server)
      log_success "Install target: VILab Server"
      install_linux_server
      return
      ;;
    desktop)
      [ "$os" = "Darwin" ] || fail "desktop install target supports macOS only in this shell script"
      log_success "Install target: macOS Desktop"
      install_macos_desktop
      return
      ;;
    auto) ;;
    *) fail "unknown VILAB_INSTALL_TARGET: $VILAB_INSTALL_TARGET" ;;
  esac

  case "$os" in
    Darwin)
      log_success "Detected macOS"
      install_macos_desktop
      ;;
    Linux)
      if is_wsl; then
        log_success "Detected WSL2; installing Linux Docker Server"
      else
        log_success "Detected Linux; installing Docker Server"
      fi
      install_linux_server
      ;;
    *)
      fail "unsupported OS: $os. Windows users should run install.ps1."
      ;;
  esac
}

main "$@"
