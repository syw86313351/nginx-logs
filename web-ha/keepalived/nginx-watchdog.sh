#!/bin/bash
# ====================================================================
# Nginx 守护脚本 — Keepalived 停机后自动恢复
# ====================================================================
# 调用方: systemd timer，每 30 秒执行一次
# 职责:   Nginx 恢复后自动拉起 Keepalived，让 VIP 回到本机
#
# 为什么需要这个脚本？
#   check_nginx.sh 发现 Nginx 挂了会用 systemctl stop keepalived
#   让 VIP 漂走。但 Nginx 恢复后，Keepalived 自己不会自动起来——
#   因为 check_nginx.sh 是 Keepalived 调用的，Keepalived 死了它也不跑了。
#   这个独立脚本负责把 Keepalived 重新拉起来。
# ====================================================================

# 如果 Keepalived 正在运行，不需要做什么
if systemctl is-active --quiet keepalived; then
    exit 0
fi

# Keepalived 没在运行，检查 Nginx 是否恢复了
if ! systemctl is-active --quiet nginx; then
    # Nginx 也没在跑，什么都不做
    exit 0
fi

# Nginx 恢复了但 Keepalived 还停着 → 拉起
echo "$(date '+%Y-%m-%d %H:%M:%S'): Nginx 已恢复，重启 Keepalived" \
    >> /var/log/keepalived-watchdog.log

systemctl start keepalived
