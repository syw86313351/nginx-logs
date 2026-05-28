#!/bin/bash
# ====================================================================
# Tomcat 后端健康检测 — 自动标记 upstream 服务器的 up/down
# ====================================================================
# 调用方:  systemd timer，每 10 秒执行一次
# 作用:    逐个探测后端 Tomcat 是否就绪，自动更新 Nginx upstream 配置
#
# 原理:
#   每台后端 Tomcat 配两份 upstream server，一个正常一个 backup:
#     server 192.168.1.10:8080 max_fails=1 fail_timeout=10s;    ← 正常工作
#     server 192.168.1.10:8080 backup;                           ← 永久热备（实际不用）
#
#   检测到 Tomcat 不可用 → 在正常 server 后面加 down 标记
#   检测到 Tomcat 恢复   → 移除 down 标记
#   upstream 变更后 → nginx -s reload 平滑生效
#
# 为什么不用 Nginx 自带的被动健康检查？
#   被动检查只有请求失败后才标记，第一个失败的请求用户会看到错误。
#   主动检测在用户请求到达之前就已经知道后端状态，不会让用户碰到故障节点。
# ====================================================================

UPSTREAM_CONF="/etc/nginx/conf.d/upstream.conf"
UPSTREAM_STATE="/var/run/nginx-upstream.state"    # 状态缓存，避免频繁 reload

# 后端列表：IP:PORT:健康检查URL
# 格式: "IP:PORT|健康检查路径"
BACKENDS=(
    "192.168.1.10:8080|/xxx/html/base/page/healthz.txt"
    "192.168.1.11:8080|/xxx/html/base/page/healthz.txt"
)

# ── 检测单个后端 ─────────────────────────────────────────────────────
check_backend() {
    local addr="$1"       # IP:PORT
    local path="$2"       # 健康检查 URL 路径
    local ip="${addr%:*}"
    local port="${addr#*:}"

    # 先试 TCP 连接（最快）
    timeout 2 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null && return 0
    # TCP 不通再试 curl（某些情况端口通了但应用没就绪）
    curl -sf --connect-timeout 3 "http://${addr}${path}" &>/dev/null && return 0
    return 1
}

# ── 重建 upstream 配置 ───────────────────────────────────────────────
rebuild_upstream() {
    local new_state="$1"

    # 和上次状态一样就不动，避免频繁 reload
    if [ -f "$UPSTREAM_STATE" ] && [ "$(cat "$UPSTREAM_STATE")" = "$new_state" ]; then
        return 0
    fi

    # 生成新的 upstream 配置
    cat > "$UPSTREAM_CONF" << 'HEADER'
# ====================================================================
# Nginx upstream — 后端 Tomcat 服务器池（自动维护 up/down）
# ====================================================================
upstream backend_pool {
    least_conn;                                             # 最少连接算法
HEADER

    local all_down=true
    for backend in "${BACKENDS[@]}"; do
        local addr="${backend%%|*}"
        local path="${backend#*|}"
        local key="${addr}"

        if echo "$new_state" | grep -q "^${key}:UP$"; then
            # 存活 → 正常 server，不标记 down
            echo "    server $addr max_fails=1 fail_timeout=10s;  # UP" >> "$UPSTREAM_CONF"
            all_down=false
        else
            # 挂了 → 标记 down，Nginx 不会往这发请求
            echo "    server $addr max_fails=1 fail_timeout=10s down;  # DOWN" >> "$UPSTREAM_CONF"
        fi
    done

    # 如果全挂了，保留所有 server 不标记 down（至少尝试连接）
    if $all_down; then
        log_warn "所有后端都挂了！保留所有 server 在线（至少尝试连接）"
        rebuild_upstream_all_up
        return
    fi

    cat >> "$UPSTREAM_CONF" << 'FOOTER'
    keepalive 32;                                           # 后端长连接复用
}
FOOTER

    # 记录状态并 reload
    echo "$new_state" > "$UPSTREAM_STATE"
    nginx -t &>/dev/null && nginx -s reload 2>/dev/null
    echo "$(date '+%H:%M:%S'): upstream 已更新 → $new_state"
}

# ── 全部标记 UP（兜底）───────────────────────────────────────────────
rebuild_upstream_all_up() {
    cat > "$UPSTREAM_CONF" << 'HEADER'
upstream backend_pool {
    least_conn;
HEADER
    for backend in "${BACKENDS[@]}"; do
        local addr="${backend%%|*}"
        echo "    server $addr max_fails=1 fail_timeout=10s;" >> "$UPSTREAM_CONF"
    done
    cat >> "$UPSTREAM_CONF" << 'FOOTER'
    keepalive 32;
}
FOOTER
    nginx -t &>/dev/null && nginx -s reload 2>/dev/null
}

# ── 主流程 ───────────────────────────────────────────────────────────
STATE=""
for backend in "${BACKENDS[@]}"; do
    addr="${backend%%|*}"
    path="${backend#*|}"
    if check_backend "$addr" "$path"; then
        STATE+="${addr}:UP"$'\n'
    else
        STATE+="${addr}:DOWN"$'\n'
        echo "$(date '+%Y-%m-%d %H:%M:%S'): $addr 不可达" >> /var/log/nginx-upstream-check.log
    fi
done

rebuild_upstream "$STATE"
