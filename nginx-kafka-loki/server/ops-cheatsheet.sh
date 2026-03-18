#!/bin/bash
# ============================================================
#  运维命令速查 — 复制粘贴即用
#  服务端执行
# ============================================================

# ════════════════════════════════════════════════
#  服务管理
# ════════════════════════════════════════════════

# 启动所有服务
docker compose up -d

# 查看所有容器状态
docker compose ps

# 查看某服务日志（实时）
docker compose logs -f vector
docker compose logs -f loki
docker compose logs -f grafana

# 重启某服务
docker compose restart vector

# 完全重建（配置变更后）
docker compose up -d --force-recreate vector


# ════════════════════════════════════════════════
#  Kafka 运维
# ════════════════════════════════════════════════

# 列出所有 topic
docker exec nla-kafka kafka-topics \
  --bootstrap-server localhost:9092 --list

# 查看 nginx-logs topic 详情（分区、副本）
docker exec nla-kafka kafka-topics \
  --bootstrap-server localhost:9092 \
  --describe --topic nginx-logs

# 查看消费者组 lag（Vector Consumer 是否跟上）
docker exec nla-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe --group vector-nginx

# 实时监控消息流入速率
docker exec nla-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe --group vector-nginx \
  --verbose

# 查看 topic 最新 10 条消息（调试用）
docker exec nla-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic nginx-logs \
  --from-beginning \
  --max-messages 10

# 手动注入一条测试日志（验证链路）
bash e2e-verify.sh

# 清空 topic（谨慎！）
docker exec nla-kafka kafka-topics \
  --bootstrap-server localhost:9092 \
  --delete --topic nginx-logs
# 然后重新初始化
bash kafka-init.sh


# ════════════════════════════════════════════════
#  Loki 运维
# ════════════════════════════════════════════════

# 检查 Loki 健康状态
curl -s http://localhost:3100/ready

# 查看所有 label（确认数据已写入）
curl -s http://localhost:3100/loki/api/v1/labels | python3 -m json.tool

# 查看 node label 的所有值
curl -s 'http://localhost:3100/loki/api/v1/label/node/values' | python3 -m json.tool

# 实时查询最新 10 条日志
curl -sG 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query={job="nginx"} | json' \
  --data-urlencode 'limit=10' | python3 -m json.tool

# 查看 Loki 存储使用量
docker exec nla-loki du -sh /loki/

# 查看摄入速率统计
curl -s http://localhost:3100/metrics | grep loki_distributor_bytes_received_total


# ════════════════════════════════════════════════
#  Vector 运维
# ════════════════════════════════════════════════

# 查看 Vector 内部指标（处理速率、错误数）
curl -s http://localhost:8686/metrics 2>/dev/null | grep -E 'processed|errors' || \
  docker exec nla-vector vector top 2>/dev/null || \
  docker logs nla-vector --tail 50

# 验证 Vector 配置语法
docker run --rm -v "$(pwd)/vector/vector.toml:/etc/vector/vector.toml:ro" \
  timberio/vector:0.39.0-alpine validate /etc/vector/vector.toml


# ════════════════════════════════════════════════
#  磁盘与数据清理
# ════════════════════════════════════════════════

# 查看各 volume 占用
docker system df -v | grep nla

# 查看 Loki 数据占用
docker exec nla-loki du -sh /loki/chunks /loki/index /loki/wal 2>/dev/null

# 查看 Kafka 数据占用
docker exec nla-kafka du -sh /var/lib/kafka/data

# 手动触发 Loki compaction（清理过期数据）
curl -X POST http://localhost:3100/loki/api/v1/admin/compaction/trigger 2>/dev/null || \
  echo "需要 Loki admin API 权限"


# ════════════════════════════════════════════════
#  常用 LogQL 查询（在 Grafana Explore 中使用）
# ════════════════════════════════════════════════

# 查看所有节点最新日志
# {job="nginx"} | json

# 5xx 错误（最近1小时）
# {job="nginx", status_class="5xx"} | json

# 慢请求（>2秒）
# {job="nginx"} | json | request_time > 2

# 某 IP 的所有请求
# {job="nginx"} | json | client_ip = "1.2.3.4"

# 某路径的错误
# {job="nginx"} | json | uri =~ "/api/.*" | status >= 400

# P99 响应时间（Metrics 面板用）
# quantile_over_time(0.99, {job="nginx"} | json | unwrap request_time [5m])

# 按 server_name 分组的 QPS
# sum by (server_name) (rate({job="nginx"}[1m]))

# 流量排行（bytes_sent）
# topk(10, sum by (uri) (sum_over_time({job="nginx"} | json | unwrap bytes_sent [1h])))

# 上游响应时间（排除无上游请求）
# avg_over_time({job="nginx"} | json | upstream_response_time != "" | unwrap upstream_response_time [5m])

# 按 SSL 协议分布
# sum by (ssl_protocol) (count_over_time({job="nginx"} | json | ssl_protocol != "" [1h]))
