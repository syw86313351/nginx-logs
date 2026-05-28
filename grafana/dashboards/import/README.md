# Grafana 仪表板 — 手动导入

本目录提供 **7 个可直接导入** 的仪表板 JSON，不依赖 provisioning 自动加载。

## 文件列表

| 文件 | 说明 |
|------|------|
| [nginx-ecterpapi-analytics.json](nginx-ecterpapi-analytics.json) | **开放平台 echterpapi**：全字段汇总表 + QPS 趋势 + 维度汇总表（含服务端/远程 IP、状态码计数）；`method`/`apiKey` 从 args+request_uri 解析；可钻取 Explore |
| [nginx-host-domain-qps.json](nginx-host-domain-qps.json) | **按中转主机 × 域名**汇总表（可点击钻取明细）+ QPS 趋势图 |
| [nginx-client-ip-stats.json](nginx-client-ip-stats.json) | **按节点查 IP**：须选 node；入口域名用 Loki 标签 **server_name**（与 nginx-analytics 一致，可选 All）；+ client_ip / remote_addr / server_addr + 28 项指标；**点击单元格 → Explore** 带 LogQL |
| [nginx-node-domains.json](nginx-node-domains.json) | 按中转节点 × 入口域名统计访问次数 + QPS 趋势 |
| [nginx-access-recent.json](nginx-access-recent.json) | 最近访问明细（全字段中文表；v6+ 支持 IP 钻取过滤） |
| [nginx-ops-overview.json](nginx-ops-overview.json) | 运营指标汇总 + 状态码趋势 |
| [nginx-troubleshoot.json](nginx-troubleshoot.json) | 慢请求/错误明细 + 4xx/5xx 趋势 |

## 导入步骤

1. 在 Grafana 中先配置好 **Loki** 数据源（能查到 `{job="nginx"}`）。
2. 左侧菜单 **Dashboards** → **New** → **Import**。
3. 点击 **Upload dashboard JSON file**，选择上述某个 `.json` 文件（或拖入）。
4. 在 **Options** 里将 **Loki** 映射到你环境中的 Loki 数据源（导入向导会提示 `DS_LOKI`）。
5. 点击 **Import**。对每个 `.json` 各重复一次。
6. 建议新建 Folder：**Nginx**，把仪表板归入同一文件夹。

## 导入顺序建议

1. `nginx-node-domains.json`  
2. `nginx-access-recent.json`（汇总表钻取目标；v6+ 支持 client_ip / remote_addr / server_addr 等 IP 过滤）  
3. `nginx-host-domain-qps.json`（按域名汇总，钻取到 access-recent）  
4. `nginx-client-ip-stats.json`（**必选** 中转主机，入口域名可选 All；钻取打开 **Explore**，数据源 uid 需为 `loki-nginx` 或改 JSON 中 explore 链接）  
5. `nginx-ops-overview.json`  
6. `nginx-troubleshoot.json`  
7. `nginx-ecterpapi-analytics.json`（开放平台接口；变量可筛 node / host / AppKey / 接口 method 等）  

## 前置条件

- Loki 中日志标签需包含：`job=nginx`、`node`、`host`、`request_method`、`status_class` 等（见仓库 `server/alloy/config-consumer.alloy`）。
- Explore 验证：

```logql
{job="nginx", node="广州Nginx中转"} | json
```

## 更新仪表板

修改 JSON 后，在 Grafana 中可再次 **Import**（选择 **Overwrite**，UID 不变会覆盖原仪表板），或在 UI 中改完后 **Share → Export** 备份。

## LogQL 说明

时序图中的 `rate(...[5m])` 使用 **固定 5 分钟窗口**（不用 `$__rate_interval` / `$__interval`，部分 Loki 插件不会替换 Grafana 宏，会报 `not a valid duration string`）。

`nginx-host-domain-qps` / `nginx-client-ip-stats` 汇总表用 `| json` 解析 IP 与 host；趋势图用 `topk(25, ...)` + 30s 步长。冻结列需 **Grafana ≥12.2**（域名表 2 列；IP 表 5 列）；当前 `server/.env` 已配置 `GRAFANA_IMAGE=grafana/grafana:12.2.1`，升级后需 `docker compose pull grafana && docker compose up -d grafana` 并重新 Import 仪表板。

`nginx-ecterpapi-analytics` 仅匹配 `uri=~".*ecterpapi.*"`；**须先选中转节点**。接口名经 `line_format`+`regexp` 从 args/request_uri 提取（避免整行 JSON 误匹配）。点击「总请求数」「访问次数」「接口方法」→ **Explore** 明细（按节点/域名/客户端 IP/接口过滤）。含维度汇总表（域名/接口/AppKey/客户端·服务端·远程 IP/流量/200·3xx·4xx·404·5xx/访问次数）。时间范围建议 ≤30m。更新后请 **Import → Overwrite**（当前 version 10）。

`nginx-client-ip-stats` 入口域名变量与 `nginx-analytics` 相同：`label_values` + `type: 1` + Loki 标签 **server_name**（Vector/Kafka-Loki 栈）；须先选中转主机。若使用 Alloy 单机栈（标签为 `host`），需改回 host 或统一采集标签。时间范围建议 ≤30m。更新 JSON 后请 **Import → Overwrite**（当前 version 22）。

更多说明见 [../../README.md](../../README.md)。
