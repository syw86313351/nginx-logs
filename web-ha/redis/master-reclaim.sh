#!/bin/bash
# ====================================================================
# app10 Redis 启动后自动抢回 Master
# ====================================================================
# 原理: Sentinel 切换后不会自动把 Master 交还给恢复的旧主。
#       这个脚本在 app10 Redis 启动后执行一次,
#       如果当前 Master 是 app11, 就触发 SENTINEL FAILOVER 抢回来。

SENTINEL_IP="192.168.131.11"
SENTINEL_PORT="26379"
REDIS_PASS="cns@2035"
LOCAL_IP="192.168.131.10"

# 等本机 Redis 就绪
for i in $(seq 1 10); do
    if redis-cli -a "$REDIS_PASS" --no-auth-warning PING &>/dev/null; then
        break
    fi
    sleep 2
done

# 问 app11 的 Sentinel: 当前 Master 是谁
CURRENT_MASTER=$(redis-cli -h "$SENTINEL_IP" -p "$SENTINEL_PORT" \
    SENTINEL MASTER redis-ha 2>/dev/null | grep "^ip$" -A1 | tail -1 | tr -d '\r')

if [ "$CURRENT_MASTER" = "$LOCAL_IP" ]; then
    echo "[reclaim] app10 已经是 Master, 无需操作"
    exit 0
fi

echo "[reclaim] 当前 Master=$CURRENT_MASTER, 触发切换回 app10"
redis-cli -h "$SENTINEL_IP" -p "$SENTINEL_PORT" SENTINEL FAILOVER redis-ha 2>/dev/null
echo "[reclaim] 完成"
