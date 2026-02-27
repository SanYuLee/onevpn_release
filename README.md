# OneVPN Release Repository

This repo hosts prebuilt OneVPN server and client binaries, organized by version under `vX.Y.Z/server` and `vX.Y.Z/client`.

## Quick install

### Windows (client)

In **PowerShell** (run as Administrator recommended), run:

```powershell
irm https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.ps1 | iex
```

The script detects architecture (32/64-bit) and downloads the matching client and wintun. No `client.yaml` is included; the first run creates it in the install dir. Configure **wg_private_key**, **wg_server_public_key**, and **server** in the Web UI, then save.

Install path: `%USERPROFILE%\onevpn-client` (default). Desktop shortcut: "OneVPN Client". Start the client (tray icon); use the Web UI to configure and start VPN.

### Linux / macOS (server or client)

**Server** (requires root):

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
```

**Client** (download to `~/onevpn-client`; you can copy files to Windows):

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | bash -s client
```

### install.sh options

- Install dir: `sudo bash -s server /opt/onevpn` or `bash -s client ~/my-client`
- Version: `sudo bash -s server /opt/onevpn 1.0.38`
- Skip systemd: `SKIP_SYSTEMD=1 curl -sSL ... | sudo bash -s server`
- Config files are not shipped; the first run creates `server.yaml` or `client.yaml` in the install dir. Use Web UI or edit the file to configure.

### Mode

Config supports `mode: wireguard` (default). Set `server`, `wg_private_key`, `wg_server_public_key` (and on server: `wg_peers`). Use `-migrate` to generate a WireGuard config from an existing file if needed.

### Install errors

- **curl (23) Failure writing output**: disk full or no write permission. Ensure enough space (e.g. 50MB) and use `sudo` for server or a writable directory.
