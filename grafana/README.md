# Nginx Loki Grafana 报表

## 手动导入（推荐）

仪表板 JSON 在 **[`dashboards/import/`](dashboards/import/)** 目录，**不自动加载**。

1. 打开 Grafana → **Dashboards** → **Import** → 上传 JSON  
2. 将 **Loki** 映射到你的数据源  
3. 共 5 个文件，详见 [`dashboards/import/README.md`](dashboards/import/README.md)

| 文件 | 用途 |
|------|------|
| `nginx-host-domain-qps.json` | 按主机查各域名 QPS |
| `nginx-node-domains.json` | 节点 × 域名访问次数 |
| `nginx-access-recent.json` | 最近访问中文明细表 |
| `nginx-ops-overview.json` | 运营总览 |
| `nginx-troubleshoot.json` | 故障排查 |

## 可选：仅自动注册 Loki 数据源

若使用本仓库 `server/docker-compose.yml`，仍会挂载 `grafana/provisioning/datasources/loki.yml`（uid: `loki`）。  
仪表板 provisioning 已关闭（`provisioning/dashboards/dashboard.yml` 中 `providers: []`）。

## 变量说明

| 变量 | 说明 |
|------|------|
| `node` | 中转节点（如 `广州Nginx中转`） |
| `host` | 入口域名 |
| `max_rows` | 明细表行数（50～500） |
| `slow_threshold` | 慢请求阈值（秒） |

## Loki 标签（Alloy 写入）

`job`、`node`、`host`、`request_method`、`status_class`、`scheme` — 详见 `server/alloy/config-consumer.alloy`。

## 性能建议（单机 Loki）

- 默认时间范围 **15m**；明细表建议 ≤100 行  
- 含 `unwrap` 的面板建议 ≤1h  

## 说明

- JSON 字段 `connection` 为连接序号，**不是**并发连接数。
