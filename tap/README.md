# TAP-Windows 驱动文件

此目录包含 TAP-Windows 驱动文件，由 OpenVPN 项目维护（版本 9.27.0）。

## 目录结构

```
tap/
├── win10/              # Windows 10 及以上版本
│   ├── amd64/          # 64 位系统
│   │   ├── OemVista.inf
│   │   ├── tap0901.cat
│   │   └── tap0901.sys
│   ├── i386/           # 32 位系统
│   ├── arm64/          # ARM64 架构（暂未使用）
│   └── include/         # 包含文件
└── win7/               # Windows 7/8
    ├── amd64/          # 64 位系统
    │   ├── OemVista.inf
    │   ├── tap0901.cat
    │   └── tap0901.sys
    ├── i386/           # 32 位系统
    ├── arm64/          # ARM64 架构（暂未使用）
    └── include/         # 包含文件
```

## 驱动选择规则

安装脚本会根据以下规则自动选择驱动：

1. **Windows 10 及以上**
   - 64 位系统：使用 `win10/amd64/` 目录
   - 32 位系统：使用 `win10/i386/` 目录

2. **Windows 7/8**
   - 64 位系统：使用 `win7/amd64/` 目录
   - 32 位系统：使用 `win7/i386/` 目录

## 驱动来源

- **版本**: 9.27.0
- **发布日期**: 2024-03-19
- **官方地址**: https://github.com/OpenVPN/tap-windows6/releases
- **维护者**: OpenVPN 官方项目

## 安装方式

### 自动安装（推荐）

运行安装脚本，脚本会自动选择合适的驱动并静默安装：

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

### 手动安装

如需手动安装，使用以下命令（需管理员权限）：

```powershell
# Windows 10+ 64 位
pnputil /add-driver "win10/amd64/OemVista.inf" /install /noreboot

# Windows 10+ 32 位
pnputil /add-driver "win10/i386/OemVista.inf" /install /noreboot

# Windows 7/8 64 位
pnputil /add-driver "win7/amd64/OemVista.inf" /install /noreboot

# Windows 7/8 32 位
pnputil /add-driver "win7/i386/OemVista.inf" /install /noreboot
```

## 驱动信息

- **ComponentId**: tap0901
- **描述**: TAP-Windows Adapter V9
- **提供商**: The OpenVPN Project

## 验证驱动安装

安装完成后，可以通过以下方式验证：

1. 打开设备管理器（Win+X → 设备管理器）
2. 展开「网络适配器」
3. 应该能看到「TAP-Windows Adapter V9」或类似名称

## 注意事项

- 安装驱动需要管理员权限
- 某些情况下安装后需要重启计算机才能生效
- 如果已安装过 TAP 驱动，脚本会跳过安装
- 卸载驱动：`pnputil /delete-driver <OEM文件名>`
