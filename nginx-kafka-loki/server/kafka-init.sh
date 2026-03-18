#!/bin/bash
# ============================================================
#  Kafka Topic 初始化脚本
#  在服务端执行: bash kafka-init.sh
#  建议在 docker compose up -d 后等 Kafka 健康再执行
# ============================================================

KAFKA_CONTAINER="${KAFKA_CONTAINER:-nla-kafka}"
BOOTSTRAP="localhost:9092"
TOPIC="nginx-logs"

# 分区数建议：客户端节点数 × 2，最少 4
# 消费者（Vector）并发线程数 = min(分区数, consumer_threads)
PARTITIONS="${PARTITIONS:-4}"
REPLICATION_FACTOR=1
RETENTION_MS=$((48 * 3600 * 1000))   # 48 小时
RETENTION_BYTES=$((5 * 1024 * 1024 * 1024))   # 5 GB

echo "=== Kafka Topic 初始化 ==="
echo "  Topic      : $TOPIC"
echo "  Partitions : $PARTITIONS"
echo "  Retention  : 48h / 5GB"
echo ""

# 等待 Kafka 就绪
echo "[1/3] 等待 Kafka 就绪..."
for i in $(seq 1 20); do
    docker exec "$KAFKA_CONTAINER" kafka-topics \
        --bootstrap-server "$BOOTSTRAP" --list > /dev/null 2>&1 && break
    echo "  等待中... ($i/20)"
    sleep 5
done

# 创建 topic（幂等操作）
echo "[2/3] 创建 topic: $TOPIC ..."
docker exec "$KAFKA_CONTAINER" kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --create \
    --if-not-exists \
    --topic "$TOPIC" \
    --partitions "$PARTITIONS" \
    --replication-factor "$REPLICATION_FACTOR" \
    --config retention.ms="$RETENTION_MS" \
    --config retention.bytes="$RETENTION_BYTES" \
    --config compression.type=lz4 \
    --config max.message.bytes=2097152

# 验证
echo "[3/3] 验证 topic 配置..."
docker exec "$KAFKA_CONTAINER" kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --describe \
    --topic "$TOPIC"

echo ""
echo "=== 完成 ==="
echo "  Kafka UI: http://$(hostname -I | awk '{print $1}'):8080"
