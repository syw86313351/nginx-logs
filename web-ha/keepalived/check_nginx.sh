#!/bin/bash
# ====================================================================
# Keepalived 健康检查脚本 — 检测 Nginx 是否存活
# ====================================================================
# 调用方:  Keepalived（通过 vrrp_script 配置，每 interval=2 秒调用一次）
# 返回值: 0 = 本机 Nginx 正常，Keepalived 保持当前状态
#        非0 = 本机 Nginx 故障 → systemctl stop keepalived → VIP 漂移到备机
#
# 为什么 Nginx 挂了要 stop keepalived 而不是降优先级？
#   keepalived 只要进程活着就会持续发 VRRP 心跳，备机收到心跳就以为 MASTER 正常。
#   stop keepalived 让心跳立即中断，备机 3 秒内发现并接管，比降级方式快 3~6 秒。
# ====================================================================

# ── 第一层: 进程检查 ──────────────────────────────────────────────────
# pidof 检查 nginx 主进程是否存在
# 最快但不够深入——进程在但 worker 僵死的情况检测不到
if ! /usr/sbin/pidof nginx &>/dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Nginx 进程不存在，停 keepalived 触发 VIP 漂移" \
        >> /var/log/keepalived-check.log
    systemctl stop keepalived 2>/dev/null || true
    exit 1
fi

# ── 第二层: 端点检查 ──────────────────────────────────────────────────
# curl 请求 /health 端点，验证 Nginx 是否真的能处理请求
# 能发现"进程在但无法响应"的情况（如 worker 全部卡死）
if command -v curl &>/dev/null; then
    if ! curl -sf --connect-timeout 2 http://127.0.0.1/health &>/dev/null; then
        # 第一次失败: 可能是瞬时抖动（如 Nginx reload），sleep 1 秒后重试
        sleep 1
        if ! curl -sf --connect-timeout 2 http://127.0.0.1/health &>/dev/null; then
            # 两次都失败: 确认 Nginx 不可用
            echo "$(date '+%Y-%m-%d %H:%M:%S'): /health 端点无响应，停 keepalived" \
                >> /var/log/keepalived-check.log
            systemctl stop keepalived 2>/dev/null || true
            exit 1
        fi
    fi
fi

exit 0
