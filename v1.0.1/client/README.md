# MyOne VPN

一个简单的VPN服务端和客户端实现，使用Go语言开发。

## 功能特性

- ✅ 基于TUN接口的虚拟网络
- ✅ AES-256-GCM加密通信
- ✅ **TLS/HTTPS伪装** - 防止DPI深度包检测
- ✅ **流量混淆** - 额外的XOR混淆层
- ✅ **DNS服务器集成** - 服务端内置DNS解析功能
- ✅ **连接复用和批处理** - 优化性能，支持全局流量代理
- ✅ **自动重连机制** - 客户端断线自动重连
- ✅ **性能优化** - 数据包批处理、缓冲区优化、可配置日志级别
- ✅ TCP隧道协议（基于TLS）
- ✅ 支持Linux服务端和Windows客户端

## 项目结构

```
myone/
├── common/          # 共享代码
│   ├── protocol.go  # 数据包协议
│   ├── crypto.go    # 加密解密
│   ├── tls.go       # TLS证书和配置
│   └── obfuscate.go # 流量混淆
├── server/          # VPN服务端（Linux）
│   └── main.go
├── client/          # VPN客户端（Windows）
│   └── main.go
└── go.mod
```

## 依赖

- Go 1.21+
- `github.com/songgao/water` - TUN/TAP接口库
- `golang.org/x/crypto` - 加密库

## 安装依赖

```bash
go mod download
```

## 编译

### 编译服务端（Linux）

```bash
./build.sh
```

### 编译客户端（Windows）

在Windows系统上：

```bash
./build.sh
```

或者交叉编译（在Linux上编译Windows版本）：

```bash
cd client
GOOS=windows GOARCH=amd64 go build -o ./one_client.exe
```

### 构建产物输出位置

`./build.sh` 会把发布产物输出到**项目同级目录**的 `../release/`（独立发布仓库）下，按版本号组织：

- 服务端：`../release/v{version}/server/one_server`
- 客户端：`../release/v{version}/client/one_client.exe`

## 使用方法

### 1. 启动服务端（Linux）

**注意：需要root权限来创建TUN接口**

```bash
# 推荐：在构建产物目录运行（会自动读取同目录 server.yaml）
cd ../release/v{version}/server
sudo ./one_server
```

参数说明：
- `-config`: 配置文件路径（YAML，默认：当前目录下的 `server.yaml`，**必需**）
- `-addr`: 服务器监听地址（默认从配置文件读取，建议使用 `:443` 伪装HTTPS）
- `-password`: VPN密码（默认从配置文件读取）
- `-tun-ip`: TUN接口IP地址（默认从配置文件读取）
- `-tun-name`: TUN接口名称（默认从配置文件读取）
- `-cert`: TLS证书文件路径（默认 `server.crt`）
- `-key`: TLS私钥文件路径（默认 `server.key`）
- `-obfuscate`: 启用流量混淆（默认从配置文件读取）
- `-dns`: DNS服务器地址（默认从配置文件读取）
- `-upstream-dns`: 上游DNS服务器（默认从配置文件读取）
- `-enable-dns`: 启用DNS服务器（默认从配置文件读取）
- `-verbose`: 启用详细日志（默认从配置文件读取）
- `-batch`: 启用数据包批处理（默认从配置文件读取）

### 2. 启动客户端（Windows）

**注意：需要管理员权限来创建TUN接口**

```bash
# 在客户端构建产物目录运行（会自动读取同目录 client.yaml）
cd ../release/v{version}/client
./one_client.exe
```

参数说明：
- `-config`: 配置文件路径（YAML，默认：当前目录下的 `client.yaml`，**必需**）
- `-server`: VPN服务器地址（默认从配置文件读取）
- `-password`: VPN密码（默认从配置文件读取）
- `-tun-ip`: TUN接口IP地址（默认从配置文件读取）
- `-tun-name`: TUN接口名称（默认从配置文件读取）
- `-insecure`: 跳过TLS证书验证（默认从配置文件读取）
- `-obfuscate`: 启用流量混淆（默认从配置文件读取，需与服务端一致）
- `-verbose`: 启用详细日志（默认从配置文件读取）
- `-batch`: 启用数据包批处理（默认从配置文件读取）
- `-reconnect`: 启用自动重连（默认从配置文件读取）
- `-reconnect-delay`: 重连延迟（默认从配置文件读取）
- `-dns-server-ip`: VPN 服务端在TUN网络中的DNS地址（默认从配置文件读取/程序默认）

### 3. Web 管理界面

- **服务端**：默认启用 Web 管理（`web_enable: true`），监听 `web_listen`（默认 `:8080`）。登录后可使用：
  - **实时日志**：SSE 流式查看运行日志
  - **配置**：查看/编辑并保存 `server.yaml`（保存后部分项需重启生效）
  - **单管理账户**：在配置中设置 `web_admin_user`、`web_admin_pass`；未设置密码时 Web 不启动
  - **防爆破**：同一 IP 密码错误 5 次封禁 15 分钟；同一 IP 每分钟最多 10 次登录请求（防 bot）

- **客户端**：默认启用 Web 管理（`web_enable: true`），仅监听本地（默认 `127.0.0.1:8081`），**无需登录**。可查看实时日志、查看/编辑并保存 `client.yaml`。**启动时自动在默认浏览器中打开** Web 页面。

配置示例（`server.yaml`）：`web_enable: true`、`web_listen: ":8080"`、`web_admin_user: "admin"`、`web_admin_pass: "强密码"`。  
客户端（`client.yaml`）：`web_enable: true`、`web_listen: "127.0.0.1:8081"`。

### 4. 路由和DNS配置（自动完成）

- **服务端（Linux）**
  - 程序启动后会自动：
    - 开启 `net.ipv4.ip_forward=1`
    - 通过 `iptables` 为 `tun` 接口和外网接口（默认 `eth0`，可通过 `-out-iface` 指定）添加 NAT 和 FORWARD 规则
  - 程序正常退出或收到终止信号时，会尽量：
    - 将 `net.ipv4.ip_forward` 恢复为原始值（如果原来不是 `1`）
    - 删除启动时添加的 `iptables` 规则

- **客户端（Windows / Linux）**
  - 客户端启动后会自动：
    - 使用 `-dns-server-ip`（默认 `10.0.0.1`）将系统 DNS 指向 VPN 服务端的内网 DNS
      - Windows：通过 `netsh interface ip set dns name=<TUN接口名> static <DNS IP>`
      - Linux：自动备份 `/etc/resolv.conf`，并写入 `nameserver <DNS IP>`
  - 客户端退出时会尽量：
    - Windows：将该接口 DNS 恢复为 DHCP
    - Linux：从备份中恢复原始 `/etc/resolv.conf`

> 如果自动配置失败（例如系统缺少 `iptables`、`sysctl` 或权限不足），程序会报错退出。此时可以根据错误信息手动排查或参考源码中的命令在系统上自行执行。

## 工作原理

1. **TUN接口**: 创建虚拟网络接口，用于捕获和注入网络数据包
2. **多层加密**: 
   - 第一层：AES-256-GCM加密（应用层加密）
   - 第二层：TLS/HTTPS传输（传输层加密，伪装成HTTPS流量）
   - 第三层：XOR流量混淆（可选，进一步隐藏流量特征）
3. **防DPI技术**:
   - **TLS伪装**: 使用标准TLS协议，流量看起来像正常的HTTPS连接
   - **端口伪装**: 默认使用443端口，与HTTPS服务相同
   - **协议特征**: TLS握手和ALPN扩展（h2, http/1.1）与真实HTTPS一致
   - **流量混淆**: XOR混淆层使数据包特征随机化
4. **性能优化**:
   - **数据包批处理**: 将多个小数据包合并发送，减少系统调用和网络开销
   - **缓冲区优化**: 可配置的缓冲区大小（默认64KB），提升吞吐量
   - **连接复用**: 单个TCP连接承载所有流量，减少连接建立开销
   - **日志级别控制**: 生产环境可关闭详细日志，减少I/O开销
5. **DNS服务**:
   - 服务端内置DNS服务器，监听在TUN网络内
   - 支持DNS缓存，提升解析速度
   - 可配置上游DNS服务器（默认Google DNS）
6. **数据转发流程**: 
   - 客户端：TUN接口 → AES加密 → XOR混淆 → 批处理 → TLS加密 → 发送到服务器
   - 服务端：接收TLS数据 → TLS解密 → 批处理 → XOR去混淆 → AES解密 → 写入TUN接口

## 防DPI特性

### TLS/HTTPS伪装
- VPN流量完全封装在TLS连接中，从网络层面看起来像正常的HTTPS流量
- 使用标准的TLS 1.2/1.3协议和常见的密码套件
- 支持HTTP/2和HTTP/1.1的ALPN扩展，进一步伪装成Web流量
- 建议使用443端口，与标准HTTPS服务端口一致

### 流量混淆
- 可选的XOR混淆层，使数据包特征随机化
- 增加DPI检测的难度
- 混淆密钥基于VPN密码派生，确保服务端和客户端同步

### 使用建议
- **端口选择**: 使用443端口（HTTPS）或80端口（HTTP）可以更好地伪装
- **证书**: 首次运行会自动生成自签名证书，生产环境建议使用有效的SSL证书
- **混淆**: 默认启用流量混淆，可以进一步提高隐蔽性

## 性能说明

### 全局流量代理性能

当客户端配置为代理全局流量时：

1. **连接复用**: 所有应用流量通过单个TLS连接传输，避免了多连接的开销
2. **批处理优化**: 小数据包会被批量处理，减少加密/解密和网络传输的开销
3. **缓冲区优化**: 64KB缓冲区可以更好地处理突发流量
4. **预期性能**:
   - **延迟**: 增加约10-50ms（取决于网络延迟和加密开销）
   - **吞吐量**: 在100Mbps网络下，可达到50-80Mbps的实际吞吐
   - **CPU使用**: 加密/解密会占用一定CPU，建议使用多核CPU

### 性能调优建议

1. **关闭详细日志**: 使用 `-verbose=false` 可提升5-10%性能
2. **启用批处理**: 使用 `-batch=true`（默认启用）可提升10-20%性能
3. **调整缓冲区**: 在 `common/performance.go` 中可调整缓冲区大小
4. **使用SSD**: 如果使用日志文件，SSD可以提升I/O性能

## 安全注意事项

⚠️ **这是一个简单的VPN实现，仅用于学习和测试目的**

- 使用强密码（建议至少16个字符）
- TLS证书在首次运行时自动生成，生产环境建议使用有效的SSL证书
- 考虑添加身份验证机制
- 定期更新密码
- 虽然使用了防DPI技术，但无法保证100%不被检测，请遵守当地法律法规

## 故障排除

### 无法创建TUN接口

- **Linux**: 确保以root权限运行，检查是否安装了TUN/TAP驱动
- **Windows**: 确保以管理员权限运行，可能需要安装TAP-Windows驱动

### 连接失败

- 检查防火墙设置
- 确认服务器地址和端口正确
- 检查密码是否一致

### 无法访问网络

- 检查服务端路由配置
- 确认IP转发已启用
- 检查iptables规则

## 许可证

MIT License

