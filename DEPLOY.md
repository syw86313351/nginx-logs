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
│   ├── README.md                       # 仪表板说明
│   ├── dashboards/import/              # ★ 手动导入用 JSON（4 个）
│   │   ├── README.md                   # 导入步骤
│   │   ├── nginx-node-domains.json
│   │   ├── nginx-access-recent.json
│   │   ├── nginx-ops-overview.json
│   │   └── nginx-troubleshoot.json
│   └── provisioning/
│       ├── datasources/loki.yml        # 可选：自动注册 Loki 数据源
│       └── dashboards/dashboard.yml    # 仪表板不自动加载（providers: []）
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

汇总表「冻结列」需 **Grafana ≥12.2**（仓库默认 `GRAFANA_IMAGE=grafana/grafana:12.2.1`）。若从 11.x 升级：

```bash
cd /path/to/nginx-logs/server
docker compose pull grafana
docker compose up -d grafana
```

升级后在 Grafana 左下角 **Grafana v12.x** 确认版本，并 **Overwrite Import** `nginx-host-domain-qps.json`。

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

   在服务端 Grafana 的 Explore 中查询 `{job="nginx", node="<node值>"}`。

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

   在服务端 Grafana 的 Explore 中查询 `{job="nginx", node="<node值>"}`。

---

## 第四部分：Grafana 分析功能

Grafana **仪表板需手动导入**（详见 [`grafana/dashboards/import/README.md`](grafana/dashboards/import/README.md)）：

| 仪表板 | 面板数 | 说明 |
|--------|--------|------|
| Nginx 节点-域名统计 | 2 | 按中转节点 × 入口域名统计访问次数；点击域名跳转明细 |
| Nginx 最近访问明细 | 1 | 全字段中文表格，最新访问在前，可调行数 |
| Nginx 运营总览 | 2 | node×host 指标汇总表 + 状态码 QPS 趋势 |
| Nginx 故障排查 | 2 | 慢请求/错误明细表 + 4xx/5xx QPS 趋势 |

**仪表板变量**（顶部下拉框）：

- `node`：中转节点（对应 JSON 日志中的 `node`，如 `广州Nginx中转`）
- `host`：入口域名（对应 JSON 中的 `host` / `server_name`）
- `request_method` / `status_class`：请求方法与状态码类（最近访问明细）
- `max_rows`：明细表显示行数（50 / 100 / 200 / 500）
- `slow_threshold`：故障排查慢请求阈值（秒）

**验证步骤**

1. 浏览器打开 `http://<服务端IP>:3000`（admin / admin）
2. **Dashboards → Import**，依次上传 `grafana/dashboards/import/` 下 4 个 JSON，并映射 Loki 数据源
3. Explore 查询：

   ```logql
   {job="nginx", node="你的node值", host="你的域名"} | json
   ```

4. 修改 Alloy 或仪表板后重启：

   ```bash
   cd server
   docker compose restart alloy-consumer grafana
   ```

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
