# Nginx 日志分析平台（单机 Docker + Kafka + Loki + Grafana）

本项目在**单机**上通过 Docker Compose 部署一套 Nginx 日志分析平台，实现：

- Nginx：反向代理，输出 JSON 结构化访问日志
- Grafana Alloy：采集 Nginx 日志（当前示例为文件 → Loki，后续可扩展到 Kafka）
- Kafka：消息队列（已在 compose 中加入，方便后续扩展日志链路）
- Loki：集中式日志存储与查询
- Grafana：仪表板展示 QPS、异常请求、响应时间等

当前目录示例重点是：**项目搭建、Nginx JSON 日志输出、Loki + Grafana 单机部署与调试**。

## 目录结构

```text
nginx-logs/
├── docker-compose.yml            # 主编排文件
├── .env                          # 环境变量 (端口、镜像版本等)
├── nginx/
│   ├── nginx.conf                # Nginx 主配置 (JSON log_format)
│   ├── conf.d/
│   │   └── default.conf          # 反向代理站点配置
│   └── logs/                     # 日志挂载目录
├── alloy/
│   └── config-producer.alloy     # Alloy 采集配置 (文件 → Loki/Kafka，示例为文件 → Loki)
├── loki/
│   └── loki-config.yml           # Loki 单机配置
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── loki.yml          # 自动配置 Loki 数据源
│   │   └── dashboards/
│   │       ├── dashboard.yml     # 仪表板 provisioning 配置
│   │       └── nginx-logs.json   # 自定义 Nginx 日志分析仪表板（占位，可按需补充）
│   └── grafana.ini               # Grafana 配置 (可选)
└── README.md
```

## 前置条件

- 已安装 Docker 和 Docker Compose
- 当前目录为 `nginx-logs`
- 端口未被占用：
  - 80：Nginx
  - 3000：Grafana
  - 3100：Loki

## 部署步骤

### 1. 启动所有服务

```bash
cd nginx-logs
docker compose up -d
```

### 2. 验证 Nginx 日志输出

1. 访问 `http://localhost` 多刷新几次，触发 Nginx 访问 httpbin。
2. 在宿主机查看日志文件（可选）：

```bash
docker compose exec nginx cat /var/log/nginx/access.log | head
```

可以看到每行是一条 JSON 日志，包含 `remote_addr`、`request_method`、`status`、`request_time` 等字段。

### 3. 验证 Loki + Grafana

1. 打开浏览器访问 `http://localhost:3000`，默认账号密码 `admin / admin`。
2. 在左侧选择 **Explore**，数据源选 `Loki`。
3. 在查询输入框输入：

```logql
{job="nginx"}
```

4. 点击 Run，可以看到刚才产生的 Nginx 访问日志。

> 后续可以在 `grafana/provisioning/dashboards/nginx-logs.json` 中补充面板，用于：
> - QPS（请求速率）
> - 状态码分布（2xx/3xx/4xx/5xx）
> - Top URI / Top IP
> - 慢请求分析（基于 `request_time`）

## 常用调试命令

```bash
# 查看整体状态
docker compose ps

# 查看某个服务日志
docker compose logs nginx
docker compose logs loki
docker compose logs grafana

# 进入 Grafana 容器手动排查
docker compose exec grafana sh
```

## 后续扩展建议（MQ + 多客户端）

- 目前示例已经：
  - 使用 Nginx JSON 日志结构化输出；
  - 使用 Loki + Grafana 做集中日志查询；
  - 在 Compose 中预留了 Kafka 服务，方便未来引入 Alloy/Kafka/Loki 流水线。
- 后续可以：
  - 在 Linux 客户端部署 Alloy（二进制或容器）采集本地 Nginx 日志，写入中心 Loki/Kafka。
  - 在 Windows 客户端使用 fluent-bit/Filebeat 采集 Nginx 日志，写入 Kafka 或 Loki。
  - 在 Grafana 中基于 LogQL 构建 QPS / 错误率 / 慢请求等仪表板与告警规则。

