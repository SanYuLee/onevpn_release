#!/usr/bin/env bash
# OneVPN 一键安装脚本（发布仓库）
# 用法（任选其一）：
#   curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
#   curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | bash -s client
# 可选参数：install.sh server [安装目录] [版本号]
#           install.sh client [安装目录] [版本号]
# 不指定版本号则自动使用仓库中的最新版本（LATEST 文件）。

set -e

REPO_RAW="https://raw.githubusercontent.com/SanYuLee/onevpn_release/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# 检测下载工具
if command -v curl &>/dev/null; then
  fetch() {
    if ! curl -sSLf "$1" -o "$2"; then
      local code=$?
      err "下载失败 (curl 退出码 $code)"
      [[ $code -eq 23 ]] && err "常见原因：磁盘已满或目标目录无写权限。请检查: df -h $INSTALL_DIR && touch $INSTALL_DIR/.write_test && rm -f $INSTALL_DIR/.write_test"
      return 1
    fi
  }
  fetch_stdout() { curl -sSLf "$1"; }
elif command -v wget &>/dev/null; then
  fetch() {
    if ! wget -q -O "$2" "$1"; then
      err "下载失败。若为写入错误，请检查磁盘空间: df -h $INSTALL_DIR"
      return 1
    fi
  }
  fetch_stdout() { wget -q -O - "$1"; }
else
  err "需要 curl 或 wget，请先安装。"
  exit 1
fi

# 解析参数：server|client [安装目录] [版本号]
MODE="${1:-}"
INSTALL_DIR="${2:-}"
VERSION_OVERRIDE="${3:-}"

if [[ "$MODE" != "server" && "$MODE" != "client" ]]; then
  echo "用法: $0 server [安装目录] [版本号]  # 安装服务端（Linux）"
  echo "      $0 client [安装目录] [版本号]  # 安装客户端（Windows 用 exe，本脚本仅下载到目录）"
  echo "示例: curl -sSL $REPO_RAW/install.sh | sudo bash -s server"
  echo "      curl -sSL $REPO_RAW/install.sh | bash -s client"
  exit 1
fi

# 解析版本号
if [[ -n "$VERSION_OVERRIDE" ]]; then
  VERSION="$VERSION_OVERRIDE"
  if [[ "$VERSION" =~ ^v ]]; then true; else VERSION="v$VERSION"; fi
else
  VERSION=$(fetch_stdout "$REPO_RAW/LATEST" | tr -d ' \r\n')
  [[ -z "$VERSION" ]] && { err "无法获取最新版本号（LATEST）。"; exit 1; }
  [[ "$VERSION" =~ ^v ]] || VERSION="v$VERSION"
fi

# 默认安装目录
if [[ -z "$INSTALL_DIR" ]]; then
  if [[ "$MODE" == "server" ]]; then
    INSTALL_DIR="/opt/onevpn"
  else
    INSTALL_DIR="${HOME}/onevpn-client"
  fi
fi

# 服务端：通常需要 root
if [[ "$MODE" == "server" ]]; then
  if [[ $(id -u) -ne 0 ]]; then
    err "安装服务端需要 root 权限，请使用: sudo bash -s server [目录]"
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 安装前检查：目标可写且磁盘空间充足（约 50MB）
if ! touch "$INSTALL_DIR/.write_test" 2>/dev/null; then
  err "无法写入 $INSTALL_DIR，请检查权限或换一个安装目录。"
  exit 1
fi
rm -f "$INSTALL_DIR/.write_test"
if command -v df &>/dev/null; then
  avail=$(df -k "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
  if [[ -n "$avail" && "$avail" -lt 51200 ]]; then
    err "磁盘空间不足（需要约 50MB），当前可用约 $((avail/1024))MB。请清理后重试。"
    exit 1
  fi
fi

BASE="$REPO_RAW/$VERSION"
if [[ "$MODE" == "server" ]]; then
  info "正在安装 OneVPN 服务端 $VERSION 到 $INSTALL_DIR ..."
  for f in one_server server.yaml VERSION README.md; do
    info "  下载 $f"
    fetch "$BASE/server/$f" "$f" || { err "下载 $f 失败"; exit 1; }
  done
  chmod +x one_server
  info "✓ 服务端文件已安装到 $INSTALL_DIR"

  # 安装 systemd 单元（可选，可通过 SKIP_SYSTEMD=1 跳过）
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
    info "已安装 systemd 单元: $SYSTEMD_UNIT"
    # 安装后自动启动服务
    if systemctl start onevpn-server 2>/dev/null; then
      info "已自动启动 onevpn-server"
    fi
  fi

  echo ""
  echo "下一步："
  echo "  - 服务已启动，提供 Web 管理界面（若已配置 web_listen / web_admin_pass）。"
  echo "  - 若未配置 VPN 参数（addr / password / tun_ip / out_iface），VPN 服务不会自动启动；可在 Web 页面完成配置后点击「启动 VPN 服务」。"
  echo "  - 管理: sudo systemctl start|stop|restart onevpn-server   # 开机自启: sudo systemctl enable onevpn-server"
  echo ""
else
  info "正在安装 OneVPN 客户端 $VERSION 到 $INSTALL_DIR ..."
  for f in one_client.exe client.yaml VERSION README.md; do
    info "  下载 $f"
    fetch "$BASE/client/$f" "$f" || { err "下载 $f 失败"; exit 1; }
  done
  info "✓ 客户端文件已安装到 $INSTALL_DIR"
  echo ""
  echo "说明：one_client.exe 为 Windows 客户端。"
  echo "  - 在 Windows 上：将本目录中文件复制到 Windows，以管理员身份运行 one_client.exe。"
  echo "  - 请先编辑 client.yaml，设置 server 与 password。"
  echo ""
fi
