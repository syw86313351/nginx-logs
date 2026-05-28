#!/bin/bash
# ====================================================================
# Redis 读写测试脚本
# ====================================================================
# 用法:
#   bash test-rw.sh              # 测本机 Redis
#   bash test-rw.sh 192.168.131.10  # 测指定 IP 的 Redis
#   bash test-rw.sh 192.168.131.11  # 测 app11（有 Sentinel 时建议用 Sentinel 地址）
# ====================================================================

PASS="cns@2035"
HOST="${1:-127.0.0.1}"
PORT="6379"
KEY="ha-test:$(date +%s)"
VALUE="test-value-$(date +%H%M%S)"

REDIS_CLI="redis-cli -h $HOST -p $PORT -a $PASS --no-auth-warning"

echo "═══════════════════════════════════════"
echo " Redis 读写测试"
echo " 目标: $HOST:$PORT"
echo "═══════════════════════════════════════"

# 1. PING
echo ""
echo "[1] PING 连接测试"
PING_RESULT=$($REDIS_CLI PING 2>/dev/null)
if [ "$PING_RESULT" = "PONG" ]; then
    echo "  ✓ PONG — 连接正常"
else
    echo "  ✗ 连接失败: $PING_RESULT"
    exit 1
fi

# 2. ROLE
echo ""
echo "[2] 当前角色"
$REDIS_CLI ROLE 2>/dev/null | head -3 | while read line; do
    echo "  $line"
done

# 3. SET
echo ""
echo "[3] 写入: SET $KEY $VALUE"
SET_RESULT=$($REDIS_CLI SET $KEY "$VALUE" 2>/dev/null)
if [ "$SET_RESULT" = "OK" ]; then
    echo "  ✓ 写入成功"
else
    echo "  ✗ 写入失败: $SET_RESULT（可能是 Slave 只读）"
fi

# 4. GET
echo ""
echo "[4] 读取: GET $KEY"
GET_RESULT=$($REDIS_CLI GET $KEY 2>/dev/null)
if [ "$GET_RESULT" = "$VALUE" ]; then
    echo "  ✓ 读取成功，值一致: $GET_RESULT"
else
    echo "  ✗ 读取失败: got=$GET_RESULT expected=$VALUE"
fi

# 5. DEL
echo ""
echo "[5] 清理: DEL $KEY"
$REDIS_CLI DEL $KEY 2>/dev/null > /dev/null
echo "  ✓ 已清理测试数据"

# 6. INFO 摘要
echo ""
echo "[6] 复制状态"
$REDIS_CLI INFO replication 2>/dev/null | grep -E "role|master_host|master_link_status|connected_slaves" | while read line; do
    echo "  $line"
done

echo ""
echo "═══════════════════════════════════════"
echo " 测试完成"
echo "═══════════════════════════════════════"
