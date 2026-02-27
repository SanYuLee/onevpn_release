# OneVPN Client

This directory contains the Windows client release: `one_client.exe`, default config generation, etc.

## Quick install

In PowerShell (run as Administrator):

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

The script installs to `%USERPROFILE%\onevpn-client` and creates a desktop shortcut. The client uses WireGuard and needs wintun.dll (the script downloads it; the client places it next to the executable on first run).

## Manual use

- **Run**: Run `one_client.exe` as Administrator. It stays in the system tray and can open the Web UI.
- **Config**: Edit `client.yaml` or use the Web UI: set `server`, `wg_private_key`, `wg_server_public_key`.
- **Tray**: Right-click the tray icon for "Show Web UI" or "Exit".
- **Restart**: Double-click the "OneVPN Client" shortcut or right-click `one_client.exe` → Run as administrator.

## Version

See the `VERSION` file in this directory.
