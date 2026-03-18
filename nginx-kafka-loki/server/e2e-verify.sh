#!/bin/bash
# ============================================================
#  端到端验证脚本
#  在服务端执行: bash e2e-verify.sh
#  功能: 构造一条测试日志 → 推入 Kafka → 等待 Vector 消费
#        → 查询 Loki 确认数据到达 → 输出结果
# ============================================================

KAFKA_CONTAINER="${KAFKA_CONTAINER:-nla-kafka}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
TOPIC="nginx-logs"
TEST_NODE="e2e-test-node"
WAIT_SECS=10

echo "=== 端到端验证 ==="

# ── 1. 构造测试日志行 ─────────────────────────────────────────
TS=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
UNIQUE_ID="e2e-$(date +%s)"
TEST_LOG=$(cat <<EOF
{"time_iso8601":"$TS","msec":"$(date +%s).000","request_time":0.042,"upstream_response_time":"0.040","upstream_connect_time":"0.001","upstream_header_time":"0.041","upstream_status":"200","remote_addr":"10.0.0.1","remote_port":"54321","x_forwarded_for":"-","x_real_ip":"203.0.113.1","node":"$TEST_NODE","server_addr":"10.0.0.100","server_port":"443","server_name":"test.example.com","scheme":"https","host":"test.example.com","request_method":"GET","request_uri":"/api/e2e-verify?id=$UNIQUE_ID","uri":"/api/e2e-verify","args":"id=$UNIQUE_ID","protocol":"HTTP/1.1","status":200,"body_bytes_sent":1234,"bytes_sent":1480,"request_length":256,"http_referer":"-","http_user_agent":"E2EVerify/1.0","http_x_request_id":"$UNIQUE_ID","request_id":"$UNIQUE_ID","connection":"12345","ssl_protocol":"TLSv1.3","ssl_cipher":"TLS_AES_256_GCM_SHA384","ssl_server_name":"test.example.com"}
EOF
)

echo "[1/4] 构造测试日志行 (id=$UNIQUE_ID)"
echo "  node: $TEST_NODE"
echo "  uri:  /api/e2e-verify?id=$UNIQUE_ID"

# ── 2. 推入 Kafka ─────────────────────────────────────────────
echo ""
echo "[2/4] 推入 Kafka topic: $TOPIC ..."
echo "$TEST_LOG" | docker exec -i "$KAFKA_CONTAINER" \
    kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "  ERROR: 推入 Kafka 失败，请检查 Kafka 是否正常运行"
    exit 1
fi
echo "  已推入 Kafka"

# ── 3. 等待 Vector 消费并写入 Loki ───────────────────────────
echo ""
echo "[3/4] 等待 Vector 消费（${WAIT_SECS}s）..."
sleep "$WAIT_SECS"

# ── 4. 查询 Loki 验证 ─────────────────────────────────────────
echo ""
echo "[4/4] 查询 Loki..."

# 用 request_id 精确查找
QUERY="{job=\"nginx\",node=\"$TEST_NODE\"} | json | request_id = \"$UNIQUE_ID\""
ENCODED_QUERY=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY" 2>/dev/null || \
    echo "$QUERY" | sed 's/ /%20/g; s/"/%22/g; s/{/%7B/g; s/}/%7D/g; s/|/%7C/g; s/=/%3D/g')

RESULT=$(curl -sf \
    "$LOKI_URL/loki/api/v1/query_range" \
    --data-urlencode "query=$QUERY" \
    --data-urlencode "limit=5" \
    --data-urlencode "start=$(date -d '-5 minutes' +%s 2>/dev/null || date -v-5M +%s)000000000" \
    --data-urlencode "end=$(date +%s)999999999" \
    2>/dev/null)

if echo "$RESULT" | grep -q "$UNIQUE_ID"; then
    echo ""
    echo "  全链路验证通过！" 
    echo "  数据已从 Kafka → Vector → Loki 完整流转"
    echo ""
    echo "  Grafana 查询语句:"
    echo "    {job=\"nginx\", node=\"$TEST_NODE\"} | json | request_id = \"$UNIQUE_ID\""
    echo ""
    echo "  Grafana URL: http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'SERVER_IP'):3000"
else
    echo ""
    echo "  未查询到测试数据，可能原因："
    echo "  1. Vector Consumer 未完成消费（尝试增大等待时间: WAIT_SECS=20 bash e2e-verify.sh）"
    echo "  2. Loki 写入延迟（查看日志: docker logs nla-vector）"
    echo "  3. Vector 配置错误（查看日志: docker logs nla-vector）"
    echo ""
    echo "  手动查询 Loki:"
    echo "    curl '$LOKI_URL/loki/api/v1/labels'"
    exit 1
fi
