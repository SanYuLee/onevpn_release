# OneVPN 服务端

本目录为 OneVPN 服务端发布包，包含 `one_server`、`server.yaml` 等。

## 一键安装（推荐）

```bash
curl -sSL https://raw.githubusercontent.com/SanYuLee/onevpn_release/main/install.sh | sudo bash -s server
```

## 手动使用

- **运行**：在本目录执行 `./one_server`（需 root，用于创建 TUN 接口）。
- **配置**：编辑 `server.yaml`，设置 `addr`、`password`、`tun_ip`、`web_listen`、`web_admin_pass` 等。
- **Web 管理**：配置 `web_listen` 与 `web_admin_pass` 后，通过浏览器访问对应地址登录管理（启停 VPN、编辑配置、查看日志等）。
- **systemd**：可将本目录配置为 systemd 服务，详见发布仓库根目录 README。

## 版本

见当前目录下 `VERSION` 文件。
