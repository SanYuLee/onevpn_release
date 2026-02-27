#!/usr/bin/env bash
# OneVPN one-line install script (release repo)
# Usage (pick one):
#   curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
#   curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | bash -s client
# Optional: install.sh server [install_dir] [version]
#           install.sh client [install_dir] [version]
# If version is omitted, the script uses the latest from the repo (LATEST file).

set -e

REPO_RAW="https://raw.githubusercontent.com/SanYuLee/onevpn_release/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect download tool
if command -v curl &>/dev/null; then
  fetch() {
    if ! curl -sSLf "$1" -o "$2"; then
      local code=$?
      err "Download failed (curl exit code $code)"
      [[ $code -eq 23 ]] && err "Common causes: disk full or no write permission. Check: df -h $INSTALL_DIR && touch $INSTALL_DIR/.write_test && rm -f $INSTALL_DIR/.write_test"
      return 1
    fi
  }
  fetch_stdout() { curl -sSLf "$1"; }
elif command -v wget &>/dev/null; then
  fetch() {
    if ! wget -q -O "$2" "$1"; then
      err "Download failed. If write error, check disk space: df -h $INSTALL_DIR"
      return 1
    fi
  }
  fetch_stdout() { wget -q -O - "$1"; }
else
  err "curl or wget is required. Please install one of them."
  exit 1
fi

# Compute local file MD5 (Linux/macOS compatible, for incremental update)
local_md5() {
  local f="$1"
  if command -v md5sum &>/dev/null; then
    md5sum "$f" 2>/dev/null | awk '{print $1}'
  elif command -v md5 &>/dev/null; then
    md5 -r "$f" 2>/dev/null | awk '{print $1}'
  else
    openssl dgst -md5 -r "$f" 2>/dev/null | awk '{print $1}'
  fi
}

# Decide if file needs download from checksums.txt (skip if MD5 unchanged)
# Usage: need_download "filename" "expected_md5" -> return 0 need download, 1 skip
need_download() {
  local f="$1" expected="$2" local_path="$INSTALL_DIR/$f"
  [[ -z "$expected" ]] && return 0
  [[ ! -f "$local_path" ]] && return 0
  local got
  got=$(local_md5 "$local_path")
  [[ "$got" == "$expected" ]]
}

# Parse args: server|client [install_dir] [version]
MODE="${1:-}"
INSTALL_DIR="${2:-}"
VERSION_OVERRIDE="${3:-}"

if [[ "$MODE" != "server" && "$MODE" != "client" ]]; then
  echo "Usage: $0 server [install_dir] [version]  # Install server (Linux)"
  echo "      $0 client [install_dir] [version]  # Install client (Windows exe; this script only downloads to dir)"
  echo "Example: curl -sSL $REPO_RAW/install.sh | sudo bash -s server"
  echo "         curl -sSL $REPO_RAW/install.sh | bash -s client"
  exit 1
fi

# Resolve version
if [[ -n "$VERSION_OVERRIDE" ]]; then
  VERSION="$VERSION_OVERRIDE"
  if [[ "$VERSION" =~ ^v ]]; then true; else VERSION="v$VERSION"; fi
else
  VERSION=$(fetch_stdout "$REPO_RAW/LATEST" | tr -d ' \r\n')
  [[ -z "$VERSION" ]] && { err "Could not get latest version (LATEST)."; exit 1; }
  [[ "$VERSION" =~ ^v ]] || VERSION="v$VERSION"
fi

# Default install directory
if [[ -z "$INSTALL_DIR" ]]; then
  if [[ "$MODE" == "server" ]]; then
    INSTALL_DIR="/opt/onevpn"
  else
    INSTALL_DIR="${HOME}/onevpn-client"
  fi
fi

# Server usually needs root
if [[ "$MODE" == "server" ]]; then
  if [[ $(id -u) -ne 0 ]]; then
    err "Installing server requires root. Use: sudo bash -s server [dir]"
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Server: stop existing service/process before install so binary can be overwritten
if [[ "$MODE" == "server" ]]; then
  if command -v systemctl &>/dev/null && systemctl stop onevpn-server 2>/dev/null; then
    info "Stopped running onevpn-server service"
  fi
  if pkill -x one_server 2>/dev/null; then
    info "Stopped running one_server process"
  fi
fi

# Pre-install check: target is writable and has enough space (~50MB)
if ! touch "$INSTALL_DIR/.write_test" 2>/dev/null; then
  err "Cannot write to $INSTALL_DIR. Check permissions or choose another install directory."
  exit 1
fi
rm -f "$INSTALL_DIR/.write_test"
if command -v df &>/dev/null; then
  avail=$(df -k "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
  if [[ -n "$avail" && "$avail" -lt 51200 ]]; then
    err "Insufficient disk space (need ~50MB). Available: about $((avail/1024))MB. Free space and retry."
    exit 1
  fi
fi

BASE="$REPO_RAW/$VERSION"
# Fetch checksums.txt (single file with server/client paths for incremental update)
declare -A CHECKSUMS
if CHECKSUMS_RAW=$(fetch_stdout "$BASE/checksums.txt" 2>/dev/null); then
  while read -r hash _ fn; do
    [[ -n "$hash" && -n "$fn" ]] && CHECKSUMS["$fn"]="$hash"
  done <<< "$CHECKSUMS_RAW"
fi

if [[ "$MODE" == "server" ]]; then
  info "Installing OneVPN server $VERSION to $INSTALL_DIR ..."
  for f in one_server VERSION README.md; do
    if ! need_download "$f" "${CHECKSUMS[server/$f]:-}"; then
      info "  Skip $f (MD5 unchanged)"
      continue
    fi
    info "  Downloading $f"
    fetch "$BASE/server/$f" "$f" || { err "Download $f failed"; exit 1; }
  done
  chmod +x one_server
  info "✓ Server files installed to $INSTALL_DIR"

  # Install systemd unit (optional; set SKIP_SYSTEMD=1 to skip)
  if [[ -z "${SKIP_SYSTEMD:-}" ]]; then
    SYSTEMD_UNIT="/etc/systemd/system/onevpn-server.service"
    cat > "$SYSTEMD_UNIT" << EOF
[Unit]
Description=OneVPN Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/one_server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    info "Installed systemd unit: $SYSTEMD_UNIT"
    # Auto-start service after install
    if systemctl start onevpn-server 2>/dev/null; then
      info "Started onevpn-server"
    fi
  fi

  # Optional: check WireGuard kernel module (needed for mode: wireguard)
  if ! (ip link add dev wg0 type wireguard 2>/dev/null; ip link del dev wg0 2>/dev/null); then
    info "Note: WireGuard kernel support not detected. For mode: wireguard install the wireguard module (e.g. apt install wireguard)."
  fi
  echo ""
  echo "Next steps:"
  echo "  - Service is running; Web UI is available if web_listen / web_admin_pass are set."
  echo "  - In server.yaml you can set mode: legacy (default) or mode: wireguard; wireguard needs wg_private_key, wg_tunnel_addr, wg_peers."
  echo "  - If VPN params are not set (addr/password or WireGuard fields), VPN will not start; configure in Web UI then click Start VPN."
  echo "  - First run creates server.yaml in the install directory; no config download needed."
  echo "  - Manage: sudo systemctl start|stop|restart onevpn-server   # Start on boot: sudo systemctl enable onevpn-server"
  echo ""
else
  info "Installing OneVPN client $VERSION to $INSTALL_DIR ..."
  for f in one_client.exe VERSION README.md; do
    if ! need_download "$f" "${CHECKSUMS[client/$f]:-}"; then
      info "  Skip $f (MD5 unchanged)"
      continue
    fi
    info "  Downloading $f"
    fetch "$BASE/client/$f" "$f" || { err "Download $f failed"; exit 1; }
  done
  info "✓ Client files installed to $INSTALL_DIR"
  echo ""
  echo "Note: one_client.exe is the Windows client (supports mode: legacy or mode: wireguard)."
  echo "  - First run creates client.yaml in the install directory; no config download needed."
  echo "  - On Windows: copy files from this directory and run one_client.exe as Administrator."
  echo "  - Legacy mode: set server and password in Web config."
  echo "  - WireGuard mode: set wg_private_key, wg_server_public_key, server (endpoint) in Web config."
  echo ""
fi
