#!/bin/bash
# ====================================================================
# Redis HA 健康监控 — 每 15 秒检查一次，发现异常自动恢复
# ====================================================================
# 运行方式: systemd timer 每 15 秒调用
# 日志:     /var/log/redis-ha-watchdog.log

PASS="cns@2035"
SENTINEL_PORT="26379"
LOCAL_IP=$(ip -4 addr show enp125s0f0-br0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
LOG="/var/log/redis-ha-watchdog.log"

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

# 本机 Redis 挂了 → 尝试拉起
if ! docker exec redis-ha redis-cli -a "$PASS" --no-auth-warning PING &>/dev/null; then
    log "Redis 无响应, 尝试重启"
    docker compose -f /opt/redis-ha/docker-compose.yml restart redis 2>/dev/null
fi

# 本机 Sentinel 挂了 → 尝试拉起
if ! docker exec sentinel-ha redis-cli -p "$SENTINEL_PORT" PING &>/dev/null; then
    log "Sentinel 无响应, 尝试重启"
    docker compose -f /opt/redis-ha/docker-compose.yml restart sentinel 2>/dev/null
fi

# 查拓扑
MASTER_IP=$(docker exec sentinel-ha redis-cli -p "$SENTINEL_PORT" SENTINEL MASTER redis-ha 2>/dev/null | grep "^ip$" -A1 | tail -1 | tr -d '\r')
ROLE=$(docker exec redis-ha redis-cli -a "$PASS" --no-auth-warning ROLE 2>/dev/null | head -1)

# 只看变化才记日志
STATE_FILE="/var/run/redis-ha-state"
CURRENT="${MASTER_IP}:${ROLE}"
LAST=$(cat "$STATE_FILE" 2>/dev/null || echo "")

if [ "$CURRENT" != "$LAST" ]; then
    log "Master=${MASTER_IP} | 本机(${LOCAL_IP})=${ROLE}"
    echo "$CURRENT" > "$STATE_FILE"
fi
