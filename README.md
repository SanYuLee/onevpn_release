# OneVPN 发布仓库

本仓库仅用于发布 OneVPN 的预编译服务端/客户端，按版本号组织在 `vX.Y.Z/server` 与 `vX.Y.Z/client` 下。

## 一键安装

### Windows 直接部署客户端

在 **Windows** 上打开 **PowerShell**（**必须右键"以管理员身份运行"**），执行一行：

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

**注意**：脚本会检测管理员权限，如果不是管理员权限会自动退出并提示。

**系统架构支持**：脚本会自动检测系统架构（32位或64位）和 Windows 版本，自动选择对应的客户端和 TAP-Windows 驱动进行下载和安装。

驱动文件与构建产物一起发布到 release 仓库，安装流程：
1. 检测管理员权限（不是管理员则退出）
2. 检测系统是否已安装 TAP 驱动
3. 根据系统架构和 Windows 版本选择对应的驱动
4. 下载客户端和驱动文件到临时目录
5. 安装驱动（使用 pnputil 静默安装）
6. 复制客户端和驱动文件到安装目录
7. 只有驱动安装成功时才启动客户端

**自动驱动安装**：脚本会自动检测系统是否已安装 TAP-Windows 驱动。如果未安装，会提示您自动下载并静默安装（无需任何额外操作，全程自动化）。

脚本会把最新版客户端（`one_client.exe`、`client.yaml` 等）下载到 `%USERPROFILE%\onevpn-client`，并创建桌面快捷方式。然后：

1. 编辑该目录下的 `client.yaml`，填写 **server**（服务器地址）和 **password**（与服务端一致）。
2. 双击桌面上的 **OneVPN 客户端** 快捷方式，或以管理员身份运行 `one_client.exe`。

**退出后再次启动**：双击桌面快捷方式「OneVPN 客户端」，或进入安装目录（如 `%USERPROFILE%\onevpn-client`）右键 `one_client.exe` → **以管理员身份运行**。程序会常驻系统托盘，右键托盘图标可「显示 Web 界面」或「退出」。

若需指定安装目录或版本号，可先下载脚本再带参数执行：

```powershell
# 下载脚本后执行（可选 -InstallDir、-Version）
.\install.ps1 -InstallDir "C:\onevpn-client" -Version "1.0.1"
```

**完全自动安装（无交互模式）**：

```powershell
# 自动下载并安装驱动，跳过所有确认提示
$env:AutoInstallTap = "1"
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
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
- **配置文件**：若安装目录下已存在 `server.yaml` 或 `client.yaml`，脚本会询问「是否覆盖？」默认不覆盖（直接回车保留现有配置）。非交互安装时默认跳过配置文件；需强制覆盖可设置 `OVERWRITE_CONFIG=1`。

安装完成后按脚本提示编辑配置并启动即可。

### 安装失败：curl (23) Failure writing output to destination

表示无法写入安装目录，常见原因：

1. **磁盘已满**：执行 `df -h /opt/onevpn`（或你的安装目录）查看剩余空间，至少需约 50MB。
2. **目录无写权限**：服务端默认安装到 `/opt/onevpn`，需用 `sudo` 运行；或指定有写权限的目录，例如 `sudo bash -s server /root/onevpn`。
3. **只读文件系统**：部分容器或只读根分区下 `/opt` 不可写，可改用可写目录：`sudo bash -s server /tmp/onevpn`，再自行将文件移到目标位置。
