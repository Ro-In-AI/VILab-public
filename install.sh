#!/usr/bin/env bash
set -euo pipefail

VILAB_RELEASE_REPO="${VILAB_RELEASE_REPO:-Ro-In-AI/VILab-public}"
VILAB_SOURCE_REPO="${VILAB_SOURCE_REPO:-orulink-ai/VILab}"
VILAB_INSTALL_DIR="${VILAB_INSTALL_DIR:-$HOME/.vilab}"
VILAB_SERVER_PORT="${VILAB_SERVER_PORT:-9876}"
VILAB_INSTALL_TARGET="${VILAB_INSTALL_TARGET:-auto}"

if [ -n "${NO_COLOR:-}" ] || [ "${TERM:-}" = "dumb" ] || [ ! -t 1 ]; then
  VILAB_COLOR=false
else
  VILAB_COLOR=true
fi

if [ "$VILAB_COLOR" = true ]; then
  RED="$(printf '\033[0;31m')"
  GREEN="$(printf '\033[0;32m')"
  YELLOW="$(printf '\033[0;33m')"
  BLUE="$(printf '\033[0;34m')"
  MAGENTA="$(printf '\033[0;35m')"
  CYAN="$(printf '\033[0;36m')"
  BOLD="$(printf '\033[1m')"
  DIM="$(printf '\033[2m')"
  NC="$(printf '\033[0m')"
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  BOLD=''
  DIM=''
  NC=''
fi

say() {
  printf '%s\n' "$*"
}

print_banner() {
  say ""
  say "${MAGENTA}${BOLD}┌─────────────────────────────────────────────────────────┐${NC}"
  say "${MAGENTA}${BOLD}│                 VILab 快速安装                         │${NC}"
  say "${MAGENTA}${BOLD}├─────────────────────────────────────────────────────────┤${NC}"
  say "${MAGENTA}${BOLD}│  声音输入能力平台：桌面客户端 + 无头服务器              │${NC}"
  say "${MAGENTA}${BOLD}└─────────────────────────────────────────────────────────┘${NC}"
  say ""
}

log_step() {
  say "${BLUE}→${NC} $*"
}

log_success() {
  say "${GREEN}✓${NC} $*"
}

log_warn() {
  say "${YELLOW}Warning:${NC} $*"
}

log_error() {
  say "${RED}✗${NC} $*" >&2
}

fail() {
  log_error "vilab install: $*"
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少依赖：$1"
}

latest_asset_url() {
  local pattern="$1"
  python3 - "$pattern" <<'PY'
import json
import re
import sys
import urllib.request

pattern = re.compile(sys.argv[1], re.IGNORECASE)
repo = sys.stdin.readline().strip()
with urllib.request.urlopen(f"https://api.github.com/repos/{repo}/releases/latest") as response:
    payload = json.load(response)

for asset in payload.get("assets", []):
    name = asset.get("name", "")
    if pattern.search(name):
        print(asset["browser_download_url"])
        sys.exit(0)

print("", end="")
sys.exit(1)
PY
}

download_latest_asset() {
  local repo="$1"
  local pattern="$2"
  local output="$3"
  need python3
  local url
  log_step "读取 $repo 的最新发布资源..."
  url="$(printf '%s\n' "$repo" | latest_asset_url "$pattern")" || true
  [ -n "$url" ] || fail "没有在 $repo 的 latest release 找到匹配资源：$pattern"
  log_step "下载：$url"
  if [ -t 1 ]; then
    curl -fL --progress-bar "$url" -o "$output"
  else
    curl -fsSL "$url" -o "$output"
  fi
  log_success "下载完成：$output"
}

install_macos_desktop() {
  log_step "检查 macOS 桌面客户端安装依赖..."
  need curl
  need python3
  local tmp
  tmp="$(mktemp -d)"
  local dmg="$tmp/VILab.dmg"
  download_latest_asset "$VILAB_RELEASE_REPO" '\.dmg$' "$dmg"
  log_step "打开 DMG，请把 VILab 拖入 Applications。"
  open "$dmg"
  print_desktop_success "macOS" "$dmg"
}

install_linux_server() {
  log_step "检查 Linux/WSL2 Server 安装依赖..."
  need curl
  need git
  need docker
  docker compose version >/dev/null 2>&1 || fail "Docker Compose 不可用，请先安装 Docker Desktop 或 docker compose plugin"
  log_success "Docker Compose 可用"

  local source_dir="$VILAB_INSTALL_DIR/source"
  mkdir -p "$VILAB_INSTALL_DIR"
  if [ -d "$source_dir/.git" ]; then
    log_step "更新源码：$source_dir"
    git -C "$source_dir" pull --ff-only
  else
    log_step "克隆 VILab 源码到：$source_dir"
    git clone --depth 1 "https://github.com/$VILAB_SOURCE_REPO.git" "$source_dir"
  fi

  log_step "启动 VILab Server Docker 服务，端口：$VILAB_SERVER_PORT"
  (
    cd "$source_dir"
    VILAB_HOST_PORT="$VILAB_SERVER_PORT" docker compose -f docker-compose.server.yml up -d --build
  )
  print_server_success "$source_dir"
}

print_desktop_success() {
  local platform="$1"
  local package_path="$2"
  say ""
  say "${GREEN}${BOLD}┌─────────────────────────────────────────────────────────┐${NC}"
  say "${GREEN}${BOLD}│                 桌面客户端安装包已准备好                │${NC}"
  say "${GREEN}${BOLD}└─────────────────────────────────────────────────────────┘${NC}"
  say ""
  say "${CYAN}${BOLD}平台：${NC} $platform"
  say "${CYAN}${BOLD}安装包：${NC} $package_path"
  say ""
  say "${CYAN}${BOLD}安装后配置：${NC}"
  say "  1. 打开 VILab 桌面客户端"
  say "  2. 在设置里选择远程 VILab Server"
  say "  3. 填入 Server URL 和 external API key"
}

print_server_success() {
  local source_dir="$1"
  say ""
  say "${GREEN}${BOLD}┌─────────────────────────────────────────────────────────┐${NC}"
  say "${GREEN}${BOLD}│                 VILab Server 已启动                    │${NC}"
  say "${GREEN}${BOLD}└─────────────────────────────────────────────────────────┘${NC}"
  say ""
  say "${CYAN}${BOLD}服务入口：${NC}"
  say "  API:  http://127.0.0.1:$VILAB_SERVER_PORT"
  say "  Docs: http://127.0.0.1:$VILAB_SERVER_PORT/docs/"
  say ""
  say "${CYAN}${BOLD}下一步：${NC}"
  say "  cd $source_dir"
  say "  docker compose -f docker-compose.server.yml exec vilab-server vilab init"
  say ""
  say "${DIM}初始化完成后，把 external API key 发给桌面客户端或 SDK 使用；不要分发 Admin Key。${NC}"
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

main() {
  local os
  os="$(uname -s)"
  print_banner

  if [ "$VILAB_INSTALL_TARGET" = "server" ]; then
    log_success "安装目标：VILab Server"
    install_linux_server
    return
  fi

  if [ "$VILAB_INSTALL_TARGET" = "desktop" ]; then
    [ "$os" = "Darwin" ] || fail "desktop 目标只支持 macOS；Windows 请使用 install.ps1，Linux/WSL2 请安装 server。"
    log_success "安装目标：macOS 桌面客户端"
    install_macos_desktop
    return
  fi

  case "$os" in
    Darwin)
      log_success "检测到平台：macOS"
      install_macos_desktop
      ;;
    Linux)
      if is_wsl; then
        log_success "检测到平台：WSL2"
        log_step "将按 Linux Docker Server 模式安装。"
      else
        log_success "检测到平台：Linux"
      fi
      install_linux_server
      ;;
    *)
      fail "当前 shell 安装脚本不支持 $os。Windows 请使用 PowerShell：irm https://raw.githubusercontent.com/$VILAB_RELEASE_REPO/main/install.ps1 | iex"
      ;;
  esac
}

main "$@"
