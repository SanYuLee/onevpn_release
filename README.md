# OneVPN 发布仓库

本仓库仅用于发布 OneVPN 的预编译服务端/客户端，按版本号组织在 `vX.Y.Z/server` 与 `vX.Y.Z/client` 下。

## 一键安装

### Windows 直接部署客户端

在 **Windows** 上打开 **PowerShell**（建议以管理员身份运行，或稍后启动客户端时会提示 UAC），执行一行：

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

**系统架构支持**：脚本会自动检测系统架构（32位或64位），下载对应的客户端程序。
**驱动策略**：脚本会下载 wintun（WireGuard）到安装目录，客户端启动时会自动放置 wintun.dll 供隧道使用。

**配置文件**：安装包不再包含 `client.yaml`。首次运行程序会在安装目录下自动生成 `client.yaml`，在 Web 界面中填写 **wg_private_key**、**wg_server_public_key**、**server** 后保存即可。

安装流程：
1. 下载客户端与 wintun 到临时目录
2. 复制到安装目录
3. 启动客户端（首次运行自动生成配置）

脚本会把最新版客户端下载到 `%USERPROFILE%\onevpn-client`，并创建桌面快捷方式。然后：

1. 首次运行会自动生成 `client.yaml`；在 Web 界面完成配置并保存。
2. 双击桌面上的 **OneVPN 客户端** 快捷方式，或以管理员身份运行 `one_client.exe`。

**退出后再次启动**：双击桌面快捷方式「OneVPN 客户端」，或进入安装目录（如 `%USERPROFILE%\onevpn-client`）右键 `one_client.exe` → **以管理员身份运行**。程序会常驻系统托盘，右键托盘图标可「显示 Web 界面」或「退出」。

若需指定安装目录或版本号，可先下载脚本再带参数执行：

```powershell
# 下载脚本后执行（可选 -InstallDir、-Version）
.\install.ps1 -InstallDir "C:\onevpn-client" -Version "1.0.1"
```

（驱动安装由客户端启动时自动完成）

### Linux / macOS：服务端或客户端

在**服务器**上安装**服务端**（需 root）：

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
```

在**本机**安装**客户端**（下载到 `~/onevpn-client`，可将文件复制到 Windows 使用）：

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | bash -s client
```

### 可选参数（install.sh）

- 指定安装目录：`sudo bash -s server /opt/onevpn` 或 `bash -s client ~/my-client`
- 指定版本号：`sudo bash -s server /opt/onevpn 1.0.1`
- 安装服务端但不安装 systemd 单元：`SKIP_SYSTEMD=1 curl -sSL ... | sudo bash -s server`
- **配置文件**：安装脚本不再下载 `server.yaml` / `client.yaml`。首次运行服务端或客户端时，程序会在安装目录下自动生成对应配置文件，存在则直接使用。
- **增量更新**：安装脚本会先获取 `checksums.txt`，若本地文件 MD5 与远程一致则跳过下载，仅更新有变化的文件。

安装完成后按脚本提示操作；首次运行会自动生成配置，在 Web 界面或编辑配置文件完成填写后启动即可。

### 运行模式（legacy / wireguard）

同一安装包支持两种数据面模式，在配置文件中设置 `mode: legacy` 或 `mode: wireguard`（默认）即可。

- **Legacy**：使用现有 TLS 隧道，配置 `server`、`password` 等即可。
- **WireGuard**：服务端需 Linux 内核 WireGuard 支持，配置 `wg_private_key`、`wg_tunnel_addr`、`wg_peers`；客户端（仅 Windows）需配置 `wg_private_key`、`wg_server_public_key`、`server`（端点）。可使用 `-migrate` 从现有配置生成 WireGuard 模板。

### 安装失败：curl (23) Failure writing output to destination

表示无法写入安装目录，常见原因：

1. **磁盘已满**：执行 `df -h /opt/onevpn`（或你的安装目录）查看剩余空间，至少需约 50MB。
2. **目录无写权限**：服务端默认安装到 `/opt/onevpn`，需用 `sudo` 运行；或指定有写权限的目录，例如 `sudo bash -s server /root/onevpn`。
3. **只读文件系统**：部分容器或只读根分区下 `/opt` 不可写，可改用可写目录：`sudo bash -s server /tmp/onevpn`，再自行将文件移到目标位置。
