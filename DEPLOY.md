# Nginx 日志分析平台 — 完整部署文档

## 架构总览

```
                        ┌─────────────────────────────────────────────┐
                        │          服务端（单机 Docker Compose）         │
                        │                                             │
                        │   Kafka ← ← ← ← ← ←    alloy-consumer     │
                        │   (9094 对外)           (Kafka → Loki)      │
                        │                              ↓              │
                        │                           Loki              │
                        │                           (3100)            │
                        │                              ↓              │
                        │                          Grafana            │
                        │                          (3000)             │
                        └───────────────────┬─────────────────────────┘
                                            │
                            ┌───────────────┼───────────────┐
                            │               │               │
                      ┌─────┴─────┐   ┌─────┴─────┐  ┌─────┴─────┐
                      │ Linux 客户端│   │ Linux 客户端│  │Windows客户端│
                      │  Nginx     │   │  Nginx     │  │  Nginx     │
                      │  Filebeat  │   │  Filebeat  │  │ Fluent Bit │
                      │  → Kafka   │   │  → Kafka   │  │  → Kafka   │
                      └───────────┘   └───────────┘  └───────────┘
```

- **服务端**：运行 Kafka + Loki + Alloy-Consumer + Grafana，做集中存储与分析。
- **客户端**：每台 Nginx 主机只跑采集 Agent（Linux 用 Filebeat，Windows 用 Fluent Bit），把日志推到服务端 Kafka。

---

## 目录结构

```text
nginx-logs/
├── server/                             # 服务端（日志平台）配置目录
│   ├── docker-compose.yml              # Kafka + Loki + Alloy-Consumer + Grafana
│   └── .env                            # 服务端环境变量（SERVER_IP、端口、镜像版本）
├── alloy/
│   └── config-consumer.alloy           # Alloy Consumer：从 Kafka 消费 → 写入 Loki
├── loki/
│   └── loki-config.yml                 # Loki 单机配置（filesystem 存储 + 7 天 retention）
├── grafana/
│   └── provisioning/
│       ├── datasources/loki.yml        # 自动注册 Loki 数据源
│       └── dashboards/
│           ├── dashboard.yml           # 仪表板自动加载
│           └── nginx-logs.json         # Nginx 日志分析仪表板
├── client-linux/                       # Linux 客户端配置模板
│   ├── filebeat.yml                    # Filebeat：采集 Nginx 日志 → Kafka
│   ├── nginx-json-log-format.conf      # Nginx JSON 日志格式片段
│   ├── logrotate-nginx                 # 日志归档（保留 7 天）
│   └── README.md                       # Linux 客户端部署手册
├── client-windows/                     # Windows 客户端配置模板
│   ├── fluent-bit.conf                 # Fluent Bit：采集 Nginx 日志 → Kafka
│   ├── parsers.conf                    # Fluent Bit JSON 解析器
│   ├── nginx-json-log-format.conf      # Nginx JSON 日志格式片段
│   └── README.md                       # Windows 客户端部署手册
├── nginx/
│   └── nginx.conf                      # Nginx 完整配置参考（含 JSON log_format 注释）
└── DEPLOY.md                           # 本文档
```

---

## 第一部分：服务端部署

### 1. 环境准备

- 一台 Linux 服务器（物理机 / 虚拟机 / 云主机均可）
- 已安装 Docker 和 Docker Compose
- 资源建议：2 核 CPU、4GB 内存、20GB+ 磁盘
- 防火墙放开端口：
  - `9094`：Kafka（客户端推送日志）
  - `3000`：Grafana（浏览器访问）
  - `3100`：Loki（可选，调试用）

### 2. 修改 `server/.env`

```bash
cd /path/to/nginx-logs/server
vi .env
```

**必须修改**：

```env
SERVER_IP=192.168.1.100    # 改成你这台服务器的真实 IP（客户端要用这个地址连 Kafka）
```

其余端口和镜像版本按需调整。

### 3. 启动服务（在 server/ 目录下）

```bash
cd /path/to/nginx-logs/server
docker compose up -d
```

检查状态：

```bash
cd /path/to/nginx-logs/server
docker compose ps
```

应该看到 4 个容器都是 `Up` 状态：`kafka`、`loki`、`alloy-consumer`、`grafana`。

### 4. 验证 Kafka

```bash
cd /path/to/nginx-logs/server
docker compose exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list
```

如果还没有 topic 是正常的，客户端第一次推送时会自动创建 `nginx-logs`。

### 5. 验证 Grafana

1. 浏览器打开：`http://<服务端IP>:3000`
2. 登录：`admin / admin`
3. 左侧选 **Explore** → 数据源选 **Loki**
4. 输入 `{job="nginx"}`，等客户端接入后就能看到日志

### 6. 服务管理

```bash
cd /path/to/nginx-logs/server
docker compose stop        # 停止
docker compose start       # 启动
docker compose restart     # 重启
docker compose down        # 停止并删除容器（数据卷保留）
docker compose down -v     # 停止并删除容器和数据卷（慎用）
docker compose logs -f     # 查看实时日志
```

---

## 第二部分：Linux 客户端部署

详细步骤见 `client-linux/README.md`，以下为概要。

### 快速步骤

1. **配置 Nginx JSON 日志**

   把 `client-linux/nginx-json-log-format.conf` 的 `log_format` 片段加到你的 `nginx.conf` 的 `http {}` 内，修改 `node` 为当前主机标识，然后 `nginx -s reload`。

2. **安装 Filebeat**

   Debian/Ubuntu：
   ```bash
   curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.17.0-amd64.deb
   sudo dpkg -i filebeat-8.17.0-amd64.deb
   ```

   CentOS/Rocky：
   ```bash
   curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.17.0-x86_64.rpm
   sudo rpm -ivh filebeat-8.17.0-x86_64.rpm
   ```

3. **配置 Filebeat**

   ```bash
   sudo cp client-linux/filebeat.yml /etc/filebeat/filebeat.yml
   ```

   修改两处：
   - `output.kafka.hosts` → `["<服务端IP>:9094"]`
   - `fields.node` → 当前主机标识

4. **启动 Filebeat**

   ```bash
   sudo systemctl enable filebeat
   sudo systemctl start filebeat
   ```

5. **配置日志归档**

   ```bash
   sudo cp client-linux/logrotate-nginx /etc/logrotate.d/nginx
   ```

6. **验证**

   在服务端 Grafana 的 Explore 中查询 `{job="nginx", host="<node值>"}`。

---

## 第三部分：Windows 客户端部署

详细步骤见 `client-windows/README.md`，以下为概要。

### 快速步骤

1. **配置 Nginx JSON 日志**

   把 `client-windows/nginx-json-log-format.conf` 的 `log_format` 片段加到你的 `nginx.conf` 的 `http {}` 内，修改 `node` 为当前主机标识，然后 `nginx -s reload`。

2. **安装 Fluent Bit**

   从 https://fluentbit.io/releases/ 下载 Windows zip 包，解压到 `C:\fluent-bit\`。

   创建目录：
   ```powershell
   mkdir C:\fluent-bit\data
   mkdir C:\fluent-bit\log
   ```

3. **配置 Fluent Bit**

   把 `client-windows/fluent-bit.conf` 和 `client-windows/parsers.conf` 复制到 `C:\fluent-bit\conf\`。

   修改 `fluent-bit.conf`：
   - `Path` → 你的 Nginx 日志路径（如 `C:\nginx\logs\access.log`）
   - `Brokers` → `<服务端IP>:9094`
   - `node` → 当前主机标识

4. **测试启动**

   ```powershell
   C:\fluent-bit\bin\fluent-bit.exe -c C:\fluent-bit\conf\fluent-bit.conf
   ```

5. **注册为 Windows 服务**

   ```powershell
   sc.exe create FluentBit binPath= "C:\fluent-bit\bin\fluent-bit.exe -c C:\fluent-bit\conf\fluent-bit.conf" start= auto
   sc.exe start FluentBit
   ```

6. **验证**

   在服务端 Grafana 的 Explore 中查询 `{job="nginx", host="<node值>"}`。

---

## 第四部分：Grafana 分析功能

启动后 Grafana 会自动加载预置仪表板，包含以下分析面板：

| 面板 | 类型 | 说明 |
|------|------|------|
| 总请求数 | Stat | 最近 5 分钟请求量 |
| 平均 QPS | Stat | 每秒请求数 |
| 4xx / 5xx 错误率 | Stat | 错误占比 |
| 请求速率（按状态码） | Time Series | 2xx/3xx/4xx/5xx 分时段趋势 |
| 状态码分布 | Pie Chart | 最近 15 分钟占比 |
| 响应时间 P50/P95/P99 | Time Series | 延迟分位数 |
| 慢请求数量 | Time Series | request_time > 0.5s 的趋势 |
| Top 10 URI | Table | 按请求量排行 |
| Top 10 错误 URI | Table | 4xx/5xx 请求量排行 |
| Top 10 IP | Table | 按访问量排行 |
| 实时日志流 | Logs | 原始日志 |
| 异常请求日志 | Logs | 仅 4xx/5xx |

**仪表板变量**（顶部下拉框）：

- `env`：按环境过滤
- `app`：按应用过滤
- `host`：按主机过滤（对应 Nginx log_format 中的 `node` 字段）
- `os`：按操作系统过滤（linux / windows）
- `status_class`：按状态码类过滤（2xx/3xx/4xx/5xx）

---

## 常用排错

### 客户端连不上 Kafka

1. 确认服务端防火墙放开了 `9094` 端口。
2. 确认 `.env` 中 `SERVER_IP` 是服务端的**真实 IP**（不是 127.0.0.1）。
3. 在客户端机器上测试连通性：
   ```bash
   telnet <服务端IP> 9094
   ```

### Grafana 看不到日志

1. 检查 `alloy-consumer` 容器日志：
   ```bash
   docker compose logs alloy-consumer
   ```
2. 检查 Kafka 中是否有消息：
   ```bash
   docker compose exec kafka kafka-console-consumer.sh \
     --bootstrap-server localhost:9092 \
     --topic nginx-logs \
     --from-beginning \
     --max-messages 5
   ```
3. 检查 Loki 是否正常：
   ```bash
   curl -s http://localhost:3100/ready
   ```

### 查看各服务日志

```bash
docker compose logs kafka
docker compose logs loki
docker compose logs alloy-consumer
docker compose logs grafana
```
