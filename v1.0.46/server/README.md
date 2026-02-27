# OneVPN Server

This directory contains the server release: `one_server`, default config generation, etc.

## Quick install

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
```

## Manual use

- **Run**: Execute `./one_server` in this directory (root required for WireGuard/NAT).
- **Config**: Edit `server.yaml` (or use Web UI): set `wg_private_key`, `wg_peers`, `web_listen`, `web_admin_pass`, etc.
- **Web**: After setting `web_listen` and `web_admin_pass`, open the URL in a browser to manage (start/stop VPN, edit config, view logs).
- **systemd**: See the release repo root README for systemd setup.

## Version

See the `VERSION` file in this directory.
