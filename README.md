# OneVPN 发布仓库

本仓库仅用于发布 OneVPN 的预编译服务端/客户端，按版本号组织在 `vX.Y.Z/server` 与 `vX.Y.Z/client` 下。

## 一键安装

### Windows 直接部署客户端

在 **Windows** 上打开 **PowerShell**（建议右键“以管理员身份运行”），执行一行：

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

脚本会把最新版客户端（`one_client.exe`、`client.yaml` 等）下载到 `%USERPROFILE%\onevpn-client`。然后：

1. 编辑该目录下的 `client.yaml`，填写 **server**（服务器地址）和 **password**（与服务端一致）。
2. 右键 `one_client.exe` → **以管理员身份运行**。

若需指定安装目录或版本号，可先下载脚本再带参数执行：

```powershell
# 下载脚本后执行（可选 -InstallDir、-Version）
.\install.ps1 -InstallDir "C:\onevpn-client" -Version "1.0.1"
```

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

安装完成后按脚本提示编辑配置并启动即可。

### 安装失败：curl (23) Failure writing output to destination

表示无法写入安装目录，常见原因：

1. **磁盘已满**：执行 `df -h /opt/onevpn`（或你的安装目录）查看剩余空间，至少需约 50MB。
2. **目录无写权限**：服务端默认安装到 `/opt/onevpn`，需用 `sudo` 运行；或指定有写权限的目录，例如 `sudo bash -s server /root/onevpn`。
3. **只读文件系统**：部分容器或只读根分区下 `/opt` 不可写，可改用可写目录：`sudo bash -s server /tmp/onevpn`，再自行将文件移到目标位置。
