# OneVPN 发布仓库

本仓库仅用于发布 OneVPN 预编译服务端/客户端，按版本号组织在 `vX.Y.Z/server` 与 `vX.Y.Z/client` 下。

## 一键安装

### Windows（客户端）

在 **PowerShell** 中（建议以管理员身份运行）执行：

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

脚本会自动检测架构（32/64 位）并下载对应客户端与 wintun。安装包不包含 `client.yaml`；首次运行会在安装目录生成。在 Web 界面中配置 **wg_private_key**、**wg_server_public_key** 与 **server** 后保存即可。

默认安装路径：`%USERPROFILE%\onevpn-client`。桌面快捷方式：「OneVPN 客户端」。启动客户端（托盘图标），在 Web 界面中完成配置并启动 VPN。

### Linux / macOS（服务端或客户端）

**服务端**（需 root）：

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
```

**客户端**（下载到 `~/onevpn-client`，可将文件复制到 Windows 使用）：

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | bash -s client
```

### install.sh 参数

- 安装目录：`sudo bash -s server /opt/onevpn` 或 `bash -s client ~/my-client`
- 版本号：`sudo bash -s server /opt/onevpn 1.0.38`
- 跳过 systemd：`SKIP_SYSTEMD=1 curl -sSL ... | sudo bash -s server`
- 不包含配置文件；首次运行会在安装目录生成 `server.yaml` 或 `client.yaml`。在 Web 界面或编辑文件中完成配置。

### 运行模式

配置支持 `mode: wireguard`（默认）。设置 `server`、`wg_private_key`、`wg_server_public_key`（服务端还需 `wg_peers`）。如需从现有配置生成 WireGuard 模板，可使用 `-migrate`。

### 安装失败

- **curl (23) Failure writing output**：磁盘空间不足或无写权限。确保有足够空间（约 50MB）并对服务端使用 `sudo` 或指定可写目录。
