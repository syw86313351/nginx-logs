# Nginx JSON 日志分析平台

**Vector Agent → Kafka → Vector Consumer → Loki → Grafana**

## 为什么加 Kafka？

JSON 日志格式每行约 500-1000 字节，高并发下（1万 QPS）每秒写入约 5-10MB。
直接推 Loki 存在三个问题：

| 问题 | 说明 |
|------|------|
| 写入抖动 | 请求洪峰时 Loki 写入压力激增，直接影响查询性能 |
| 无缓冲 | Loki 重启或网络抖动导致日志丢失 |
| 并发汇聚 | 多台机器同时推送，Loki 面临大量并发写入连接 |

## 技术选型

| 组件 | 作用 | 为何选它 |
|------|------|---------|
| **Vector Agent** | 客户端 tail → Kafka | Rust 内存 ~15MB；原生 Kafka output；断点续读 |
| **Kafka** | 消息缓冲 | 高吞吐；lz4 压缩减少 60-70% 大小；48h 缓冲窗口 |
| **Vector Consumer** | Kafka → 解析 → Loki | 字段规范化；批量写入降低 Loki 压力 |
| **Loki** | 日志存储 | 按标签索引，磁盘占用远低于 ES |
| **Grafana** | 可视化 + 告警 | 原生 Loki 数据源；LogQL 做聚合计算 |
| **Kafka UI** | Kafka 监控 | 查看 topic lag、消费进度 |

## 目录结构

```
nginx-kafka-loki/
├── server/
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── kafka-init.sh                    # Kafka topic 初始化
│   ├── e2e-verify.sh                    # 端到端链路验证
│   ├── ops-cheatsheet.sh                # 运维命令速查
│   ├── vector/vector.toml               # Kafka 消费 → 解析 → Loki
│   ├── loki/config.yml                  # 存储、保留、写入优化
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/loki.yml
│       │   ├── dashboards/default.yml
│       │   └── alerting/
│       │       ├── nginx-alerts.yml     # 4 条告警规则
│       │       └── contact-points.yml  # 钉钉/企微/Webhook
│       └── dashboards/nginx-analytics.json
├── client-linux/
│   ├── docker-compose.yml
│   ├── vector-agent.toml
│   └── .env.example
└── client-windows/
    ├── vector-agent.toml
    └── install.ps1
```

---

## 部署步骤

### 一、服务端

```bash
cd server
cp .env.example .env
vim .env                # 填写 SERVER_IP

docker compose up -d
bash kafka-init.sh      # 预建分区（推荐）
bash e2e-verify.sh      # 验证全链路
```

| 服务 | 地址 |
|------|------|
| Grafana | `http://SERVER_IP:3000`（admin/见.env）|
| Kafka UI | `http://SERVER_IP:8080` |

### 二、Linux 客户端

```bash
cd client-linux
cp .env.example .env
vim .env                # 填写 KAFKA_BROKERS=SERVER_IP:9093
docker compose up -d
docker compose logs -f vector-agent
```

### 三、Windows 客户端

管理员 PowerShell：

```powershell
.\install.ps1 -KafkaBrokers "192.168.1.100:9093" -NodeName "ws01" -NginxLogPath "C:\nginx\logs\access.log"
```

---

## 数据流

```
nginx access.log (JSON ~800B/行)
  → Vector Agent (tail + lz4)
  → Kafka topic:nginx-logs (缓冲 48h/5GB)
  → Vector Consumer (批量消费)
      parse_json → status_class 标签 → client_ip 提取 → upstream "-" → null
  → Loki (按低基数标签索引)
  → Grafana Dashboard + 告警
```

## Loki 标签

只将低基数字段设为标签：`job` / `node` / `server_name` / `scheme` / `request_method` / `status_class`

`uri`、`client_ip`、`http_user_agent` 等高基数字段留在日志体，通过 `| json | field = "value"` 过滤。

## 告警规则

| 规则 | 条件 | 持续 |
|------|------|------|
| 5xx 错误率过高 | > 1% | 2m |
| P99 响应时间过高 | > 3s | 3m |
| 节点日志中断 | 5min 无日志 | 立即 |
| 流量骤降 | QPS 降至历史 30% | 5m |

编辑 `grafana/provisioning/alerting/contact-points.yml` 填入 Webhook 地址。

## 常见问题

**Kafka lag 持续增大（Consumer 跟不上）**
```bash
# 增加分区
docker exec nla-kafka kafka-topics --bootstrap-server localhost:9092 \
  --alter --topic nginx-logs --partitions 8
# 同步调大 vector/vector.toml 中 [sinks.loki.request] concurrency = 8
docker compose restart vector
```

**Grafana 无数据**
```bash
curl -s 'http://localhost:3100/loki/api/v1/label/job/values'
# 在 Explore 中查: {job="nginx"}
```

**Loki 磁盘增长过快**
```bash
# 修改 loki/config.yml → retention_period: 7d
docker compose restart loki
```
