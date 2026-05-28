#!/bin/sh
# ====================================================================
# Redis 启动脚本 — 自动处理 Master 不可达的情况
# ====================================================================
# 正常流程:
#   app10 先启动 (Master) → app11 后启动 (Slave) → 自动同步 ✓
#
# 异常流程（app10 从没启动过）:
#   1. 启动 Redis，带着 --replicaof 参数，尝试连 Master
#   2. 等待一段时间，如果 Master 一直不可达
#   3. 自动执行 REPLICAOF NO ONE，把自己提升为 Master
# ====================================================================

MASTER_IP="192.168.131.10"
MASTER_PORT="6379"
REDIS_PASS="cns@2035"
WAIT_TIMEOUT=10       # 等 10 秒，试联网也可以再长点

# 后台启动 Redis
redis-server "$@" &
REDIS_PID=$!

# 如果配置了 replicaof，等待 Master 可达
if echo "$@" | grep -q "replicaof"; then
    echo "[init] 检测到 Slave 模式, 等待 Master ${MASTER_IP}:${MASTER_PORT}..."

    for i in $(seq 1 $WAIT_TIMEOUT); do
        if redis-cli -h "$MASTER_IP" -p "$MASTER_PORT" -a "$REDIS_PASS" --no-auth-warning PING >/dev/null 2>&1; then
            echo "[init] Master 可达 ✓, 保持 Slave 模式"
            break
        fi
        sleep 1
    done

    # 等完了还连不上 → 自己当 Master
    if ! redis-cli -h "$MASTER_IP" -p "$MASTER_PORT" -a "$REDIS_PASS" --no-auth-warning PING >/dev/null 2>&1; then
        echo "[init] Master 不可达, 提升自己为 Master"
        sleep 2
        redis-cli -a "$REDIS_PASS" --no-auth-warning REPLICAOF NO ONE 2>/dev/null
        echo "[init] 已提升为 Master ✓"
    fi
fi

# 等 Redis 主进程
wait $REDIS_PID
