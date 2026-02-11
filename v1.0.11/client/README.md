# OneVPN 客户端

本目录为 OneVPN 客户端发布包，包含 `one_client.exe`、`client.yaml` 等，用于 Windows。

## 一键安装（推荐）

在 Windows PowerShell 中执行：

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

脚本会下载到 `%USERPROFILE%\onevpn-client` 并创建桌面快捷方式。
客户端启动时会自动检测并安装 TAP-Windows 驱动（需管理员权限），驱动文件已随脚本下载到安装目录的 `tap/` 下。

## 手动使用

- **运行**：以管理员身份运行 `one_client.exe`。程序会常驻系统托盘，并自动打开 Web 管理界面。
- **配置**：编辑 `client.yaml`，设置 `server`（服务端地址）与 `password`（与服务端一致）；或在 Web 页面中编辑并保存。
- **托盘**：右键托盘图标可「显示 Web 界面」或「退出」。
- **再次启动**：双击桌面「OneVPN 客户端」快捷方式，或到本目录右键 `one_client.exe` → 以管理员身份运行。

## 版本

见当前目录下 `VERSION` 文件。
