#!/bin/bash
#=============================================================================
#
#  Nginx + Keepalived + Redis + Sentinel (Docker Compose) 高可用集群部署脚本
#  =====================================================================
#
#  适用系统: openEuler 24
#  架构:     app10 (MASTER) + app11 (BACKUP)
#
#  ┌─ Nginx HA ──────────────────────────────────────┐
#  │  机制: Keepalived VRRP + VIP                     │
#  │  部署: 宿主机直接安装 (dnf)                       │
#  └─────────────────────────────────────────────────┘
#
#  ┌─ Redis HA ─────────────────────────────────────┐
#  │  机制: Redis 主从 + Sentinel 自动故障转移        │
#  │  部署: Docker Compose (redis:7-alpine 镜像)     │
#  │  网络: host 模式 (直连宿主机网络栈)              │
#  └─────────────────────────────────────────────────┘
#
#  为什么 Redis 用 Docker 而 Nginx/Keepalived 不用？
#  - Keepalived 需要操作内核 VIP（ip addr add/del），需要 CAP_NET_ADMIN，
#    容器化复杂且不稳定，宿主机部署最可靠
#  - Nginx 和 Keepalived 在同一宿主机上，配合简单
#  - Redis 无特殊内核需求，Docker 部署隔离好、升级方便、配置清晰
#
#  五个阶段:
#    一 — 环境检查
#    二 — 软件安装 (Nginx+Keepalived+Docker)
#    三 — 配置生成 (Keepalived+Nginx+Docker Compose)
#    四 — 服务调测 (逐个启动验证)
#    五 — 上线检查
#
#  用法:
#    bash HA-nginx-setup.sh master   # app10
#    bash HA-nginx-setup.sh backup   # app11
#=============================================================================

set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                      【可修改变量区】                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

INTERFACE="enp125s0f0-br0"
VIP="192.168.131.100"
APP10_IP="192.168.131.10"
APP11_IP="192.168.131.11"

VRRP_ID="51"
MASTER_PRIORITY="100"
BACKUP_PRIORITY="90"
AUTH_PASS="YourAuthPass123"

BACKEND_SERVERS=(
    "192.168.1.10:8080"
    "192.168.1.11:8080"
)

REDIS_PASSWORD="YourRedisPass123"
SENTINEL_QUORUM="1"
REDIS_PORT=6379
SENTINEL_PORT=26379
REDIS_MAXMEMORY="512mb"

# Docker Compose 部署目录（所有 Redis 相关文件都在这里）
REDIS_COMPOSE_DIR="/opt/redis-ha"

AUTO_YES=false

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                        参数解析 & 工具函数                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

ROLE=""
for arg in "$@"; do
    case "$arg" in
        master) ROLE="master" ;;
        backup) ROLE="backup" ;;
        --yes)  AUTO_YES=true ;;
        *)      echo "用法: bash $0 [master|backup] [--yes]"; exit 1 ;;
    esac
done

if [[ -z "$ROLE" ]]; then
    echo "用法: bash $0 [master|backup] [--yes]"
    echo "  master — app10: Nginx MASTER + Redis 初始 Master"
    echo "  backup — app11: Nginx BACKUP + Redis Slave"
    exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

confirm() {
    if $AUTO_YES; then return 0; fi
    echo ""; read -r -p ">>> 按回车继续，或 Ctrl+C 退出... "
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              第一阶段：环境检查                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

phase1_check() {
    log_step "第一阶段：环境检查"

    log_info "系统版本..."
    cat /etc/openEuler-release 2>/dev/null || log_warn "非 openEuler 系统"

    [ "$(id -u)" = "0" ] || { log_error "需要 root 权限！"; exit 1; }
    log_info "root ✓"

    ip link show "$INTERFACE" &>/dev/null || { log_error "网卡 $INTERFACE 不存在！可用:"; ip -br link show; exit 1; }
    log_info "网卡 $INTERFACE 存在 ✓"

    LOCAL_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    [ -n "$LOCAL_IP" ] && log_info "本机 IP: $LOCAL_IP ✓" || { log_error "获取 IP 失败"; exit 1; }

    ping -c 1 -W 1 "$VIP" &>/dev/null && log_warn "VIP $VIP 可 ping 通，可能已被占用" || log_info "VIP $VIP 空闲 ✓"

    log_info "端口检查..."
    for port in 80 443 "$REDIS_PORT" "$SENTINEL_PORT"; do
        ss -tlnp | grep -q ":$port " && log_warn "端口 $port 已占用" || log_info "端口 $port 空闲 ✓"
    done

    log_info "Docker 是否已安装..."
    docker --version 2>/dev/null && log_info "Docker 已安装 ✓" || log_info "Docker 未安装，将在第二阶段安装"

    log_info "SELinux: $(getenforce 2>/dev/null || echo '未安装')"
    [ "$(getenforce 2>/dev/null)" = "Enforcing" ] && log_warn "建议暂时关闭: setenforce 0"

    log_info "第一阶段 完成 ✓"
    confirm
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              第二阶段：软件安装                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

phase2_install() {
    log_step "第二阶段：软件安装"

    dnf install -y epel-release 2>/dev/null || true

    # ── Nginx ──
    log_info "安装 Nginx..."
    dnf install -y nginx
    log_info "Nginx $(nginx -v 2>&1) ✓"

    # ── Keepalived ──
    log_info "安装 Keepalived..."
    dnf install -y keepalived
    log_info "Keepalived $(keepalived --version 2>&1 | head -1) ✓"

    # ── Docker + Docker Compose ──
    #
    # openEuler 24 上 Docker 的安装方式:
    #   1. 优先用 dnf 自带的 docker (如果可用)
    #   2. 否则从官方仓库安装
    #
    log_info "安装 Docker Engine..."
    if ! command -v docker &>/dev/null; then
        # 尝试 dnf 安装
        dnf install -y docker-ce docker-ce-cli containerd.io 2>/dev/null || \
        dnf install -y docker docker-compose 2>/dev/null || {
            log_warn "dnf 源中未找到 Docker，尝试从官方仓库安装..."
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
            dnf install -y docker-ce docker-ce-cli containerd.io 2>/dev/null || {
                log_error "Docker 安装失败！请手动安装 Docker 后重试。"
                log_error "参考: https://docs.docker.com/engine/install/"
                exit 1
            }
        }
    fi

    # 启动 Docker
    systemctl enable docker
    systemctl start docker
    docker --version && log_info "Docker 就绪 ✓" || { log_error "Docker 启动失败"; exit 1; }

    # ── Docker Compose Plugin ──
    log_info "安装 Docker Compose..."
    if ! docker compose version &>/dev/null; then
        # Docker Compose v2 (plugin)
        dnf install -y docker-compose-plugin 2>/dev/null || {
            log_warn "docker-compose-plugin 不在源中，手动安装..."
            COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep tag_name | cut -d'"' -f4 | head -1)
            COMPOSE_VER=${COMPOSE_VER:-v2.27.0}
            mkdir -p /usr/local/lib/docker/cli-plugins
            curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-linux-x86_64" \
                -o /usr/local/lib/docker/cli-plugins/docker-compose
            chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
        }
    fi
    docker compose version && log_info "Docker Compose 就绪 ✓" || { log_error "Docker Compose 安装失败"; exit 1; }

    # ── 辅助工具 ──
    dnf install -y psmisc net-tools curl

    # ── 拉取 Redis 镜像（提前拉好，避免部署时等） ──
    log_info "拉取 Redis 镜像..."
    docker pull redis:7-alpine
    log_info "Redis 镜像就绪 ✓"

    log_info "第二阶段 完成 ✓"
    confirm
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              第三阶段：配置生成                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

phase3_config() {
    log_step "第三阶段：配置生成"

    if [[ "$ROLE" == "master" ]]; then
        PRIORITY="$MASTER_PRIORITY"
        STATE="MASTER"
        ROUTER_ID="NGINX_HA_1"
        LOCAL_NAME="app10"
        REDIS_ROLE="master"
    else
        PRIORITY="$BACKUP_PRIORITY"
        STATE="BACKUP"
        ROUTER_ID="NGINX_HA_2"
        LOCAL_NAME="app11"
        REDIS_ROLE="slave"
    fi

    # ── 3.1 Nginx 健康检查脚本 ───────────────────────────────────────
    log_info "生成 /etc/keepalived/check_nginx.sh ..."
    cat > /etc/keepalived/check_nginx.sh << 'SCRIPT_EOF'
#!/bin/bash
if ! /usr/sbin/pidof nginx &>/dev/null; then
    echo "$(date): Nginx 进程不存在，停止 keepalived" >> /var/log/keepalived-check.log
    systemctl stop keepalived 2>/dev/null || true; exit 1
fi
if command -v curl &>/dev/null; then
    if ! curl -sf --connect-timeout 2 http://127.0.0.1/health &>/dev/null; then
        sleep 1
        if ! curl -sf --connect-timeout 2 http://127.0.0.1/health &>/dev/null; then
            echo "$(date): /health 无响应" >> /var/log/keepalived-check.log
            systemctl stop keepalived 2>/dev/null || true; exit 1
        fi
    fi
fi
exit 0
SCRIPT_EOF
    chmod +x /etc/keepalived/check_nginx.sh

    # ── 3.2 Keepalived ───────────────────────────────────────────────
    log_info "生成 /etc/keepalived/keepalived.conf ..."
    cat > /etc/keepalived/keepalived.conf << CONF_EOF
global_defs {
    router_id ${ROUTER_ID}
    script_user root
    enable_script_security
}
vrrp_script chk_nginx {
    script      "/etc/keepalived/check_nginx.sh"
    interval    2
    weight      -20
    fall        3
    rise        2
}
vrrp_instance VI_1 {
    state ${STATE}
    interface ${INTERFACE}
    virtual_router_id ${VRRP_ID}
    priority ${PRIORITY}
    advert_int 1
    unicast_peer { ${APP10_IP} ${APP11_IP} }
    authentication { auth_type PASS; auth_pass ${AUTH_PASS}; }
    virtual_ipaddress { ${VIP}/24 dev ${INTERFACE}; }
    track_script { chk_nginx; }
    notify_master "/bin/echo '\$(date): 晋升 MASTER, VIP=${VIP}' >> /var/log/keepalived-notify.log"
    notify_backup "/bin/echo '\$(date): 降级 BACKUP' >> /var/log/keepalived-notify.log"
    notify_fault  "/bin/echo '\$(date): FAULT!' >> /var/log/keepalived-notify.log"
}
CONF_EOF

    # ── 3.3 Nginx upstream ───────────────────────────────────────────
    log_info "生成 /etc/nginx/conf.d/upstream.conf ..."
    UPSTREAM_SERVERS=""
    for srv in "${BACKEND_SERVERS[@]}"; do
        UPSTREAM_SERVERS+="        server $srv max_fails=3 fail_timeout=30s;"$'\n'
    done
    cat > /etc/nginx/conf.d/upstream.conf << NGX_EOF
upstream backend_pool {
    least_conn;
${UPSTREAM_SERVERS}
    keepalive 32;
}
NGX_EOF

    # ── 3.4 Nginx 虚拟主机 ───────────────────────────────────────────
    log_info "生成 /etc/nginx/conf.d/virtual-host.conf ..."
    cat > /etc/nginx/conf.d/virtual-host.conf << 'NGX_EOF'
server {
    listen 80;
    server_name _;
    access_log /var/log/nginx/ha-access.log;
    error_log  /var/log/nginx/ha-error.log warn;
    location = /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
    location / {
        proxy_pass http://backend_pool;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection        "";
        proxy_connect_timeout 5s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
        proxy_buffering        on;
        proxy_buffer_size      4k;
        proxy_buffers          8 16k;
        proxy_busy_buffers_size 32k;
    }
}
NGX_EOF

    # ── 3.5 Nginx 主配置优化 ─────────────────────────────────────────
    [ ! -f /etc/nginx/nginx.conf.bak ] && cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    sed -i 's/worker_processes\s\+[0-9]\+/worker_processes auto/' /etc/nginx/nginx.conf 2>/dev/null || true
    sed -i 's/worker_connections\s\+[0-9]\+/worker_connections 4096/' /etc/nginx/nginx.conf 2>/dev/null || true

    # ── 3.6 Docker Compose: Redis + Sentinel ─────────────────────────
    #
    # 为什么用 Docker 部署 Redis？
    #   - 隔离：Redis 不污染宿主机环境，升级/卸载干净
    #   - 便利：docker compose up/down 一键启停
    #   - 可迁移：同一份 compose 文件可以搬到任何装了 Docker 的机器
    #
    # 为什么用 host 网络模式？
    #   - Redis 和 Sentinel 需要在宿主机 IP 上监听，供另一台机器连接
    #   - host 模式下容器直接使用宿主机网络栈，性能最好
    #   - 跨机器主从复制不需要额外配置端口映射
    #
    log_info "生成 Docker Compose 配置 ${REDIS_COMPOSE_DIR}/docker-compose.yml ..."
    mkdir -p "$REDIS_COMPOSE_DIR"

    # 构建 Redis 命令行参数
    REDIS_CMD="redis-server --port ${REDIS_PORT} --requirepass ${REDIS_PASSWORD} --masterauth ${REDIS_PASSWORD} --maxmemory ${REDIS_MAXMEMORY} --maxmemory-policy allkeys-lru --save \"\" --appendonly no --loglevel notice"

    # app11 需要加上 replicaof
    if [[ "$REDIS_ROLE" == "slave" ]]; then
        REDIS_CMD="${REDIS_CMD} --replicaof ${APP10_IP} ${REDIS_PORT}"
    fi

    cat > "${REDIS_COMPOSE_DIR}/docker-compose.yml" << COMPOSE_EOF
# ====================================================================
# Redis + Sentinel 高可用 — Docker Compose
# ====================================================================
# 文件位置: ${REDIS_COMPOSE_DIR}/docker-compose.yml
# 本机角色: ${REDIS_ROLE}
#
# 管理命令:
#   启动:  docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml up -d
#   停止:  docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml down
#   重启:  docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml restart
#   日志:  docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml logs -f
#   状态:  docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml ps
# ====================================================================

services:

  # ── Redis 数据节点 ──────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    container_name: redis-ha
    network_mode: host            ! 使用宿主机网络，监听宿主机 IP
    restart: always               ! 崩溃自动重启
    command: >
      ${REDIS_CMD}
    volumes:
      - ${REDIS_COMPOSE_DIR}/redis-data:/data   ! 持久化目录（虽然禁用了 RDB/AOF，预留）
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "--no-auth-warning", "PING"]
      interval: 10s
      timeout: 3s
      retries: 3

  # ── Sentinel 哨兵 ────────────────────────────────────────────────
  sentinel:
    image: redis:7-alpine
    container_name: sentinel-ha
    network_mode: host            ! 和 Redis 一样用宿主机网络
    restart: always
    command: >
      redis-sentinel /etc/sentinel.conf --port ${SENTINEL_PORT}
    volumes:
      # Sentinel 配置文件通过宿主机文件挂载进去
      - ${REDIS_COMPOSE_DIR}/sentinel.conf:/etc/sentinel.conf:ro
    depends_on:
      redis:
        condition: service_healthy   ! 等 Redis 健康后再启动 Sentinel
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "${SENTINEL_PORT}", "PING"]
      interval: 10s
      timeout: 3s
      retries: 3
COMPOSE_EOF

    # ── 3.7 Sentinel 配置文件 ────────────────────────────────────────
    #
    # Sentinel 配置文件单独写一个文件，挂载到 Sentinel 容器里。
    # 注意: Sentinel 运行时会修改这个文件（写入当前状态），
    # 所以不应该用 :ro 挂载。这里先写一个初始配置，
    # 第一次启动后会由 Sentinel 自动更新。
    #
    log_info "生成 Sentinel 配置 ${REDIS_COMPOSE_DIR}/sentinel.conf ..."

    cat > "${REDIS_COMPOSE_DIR}/sentinel.conf" << SENTINEL_EOF
# ====================================================================
# Redis Sentinel 配置
# ====================================================================
# 集群名: redis-ha
# Master:  ${APP10_IP}:${REDIS_PORT}
# Quorum:  ${SENTINEL_QUORUM}

# 监控 Master
sentinel monitor redis-ha ${APP10_IP} ${REDIS_PORT} ${SENTINEL_QUORUM}

# Master 认证密码
sentinel auth-pass redis-ha ${REDIS_PASSWORD}

# 主观下线判定: 5 秒无响应
sentinel down-after-milliseconds redis-ha 5000

# 故障转移超时: 60 秒
sentinel failover-timeout redis-ha 60000

# 并行同步从节点数
sentinel parallel-syncs redis-ha 1
SENTINEL_EOF

    # ── 3.8 内核参数 & 防火墙 ─────────────────────────────────────────
    log_info "配置内核参数和防火墙..."
    cat > /etc/sysctl.d/99-nginx-ha.conf << SYSCTL_EOF
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.conf.all.arp_ignore    = 1
net.ipv4.conf.all.arp_announce  = 2
net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.default.arp_announce = 2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 4096
SYSCTL_EOF
    sysctl --system > /dev/null 2>&1

    firewall-cmd --permanent --add-service=http 2>/dev/null || true
    firewall-cmd --permanent --add-service=https 2>/dev/null || true
    firewall-cmd --permanent --add-rich-rule='rule protocol value="vrrp" accept' 2>/dev/null || true
    firewall-cmd --permanent --add-port="${REDIS_PORT}/tcp" 2>/dev/null || true
    firewall-cmd --permanent --add-port="${SENTINEL_PORT}/tcp" 2>/dev/null || true
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${APP10_IP}' accept" 2>/dev/null || true
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${APP11_IP}' accept" 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true

    log_info "第三阶段 完成 ✓ 配置文件:"
    echo "  /etc/keepalived/keepalived.conf          — Keepalived VRRP"
    echo "  /etc/keepalived/check_nginx.sh            — Nginx 健康检查"
    echo "  /etc/nginx/conf.d/upstream.conf           — 后端服务器池"
    echo "  /etc/nginx/conf.d/virtual-host.conf        — 反向代理"
    echo "  ${REDIS_COMPOSE_DIR}/docker-compose.yml   — Redis + Sentinel (Docker)"
    echo "  ${REDIS_COMPOSE_DIR}/sentinel.conf        — Sentinel 配置"
    confirm
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              第四阶段：服务调测                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

phase4_debug() {
    log_step "第四阶段：服务调测"

    # ── 4.1 Nginx ─────────────────────────────────────────────────────
    log_info "Nginx 语法检查..."
    nginx -t || { log_error "Nginx 语法错误！"; exit 1; }

    log_info "启动 Nginx..."
    systemctl enable nginx
    systemctl restart nginx
    sleep 1
    systemctl is-active --quiet nginx && log_info "Nginx 运行中 ✓" || { log_error "Nginx 启动失败"; exit 1; }

    log_info "测试 /health..."
    curl -sf --connect-timeout 2 http://127.0.0.1/health && log_info "/health OK ✓" || { log_error "/health 无响应"; exit 1; }

    # ── 4.2 Keepalived ────────────────────────────────────────────────
    log_info "启动 Keepalived..."
    systemctl enable keepalived
    systemctl restart keepalived
    sleep 3
    systemctl is-active --quiet keepalived && log_info "Keepalived 运行中 ✓" || { log_error "Keepalived 启动失败"; exit 1; }

    log_info "VIP 绑定检查..."
    if ip addr show "$INTERFACE" | grep -q "$VIP"; then
        log_info "VIP ($VIP) 已绑定 ✓"
    else
        [ "$ROLE" = "backup" ] && log_info "VIP 未绑定 — BACKUP 正常" || log_warn "VIP 未绑定！检查 journalctl -u keepalived -n 20"
    fi

    # ── 4.3 Docker Compose (Redis + Sentinel) ──────────────────────────
    log_info "启动 Redis + Sentinel (Docker Compose)..."
    cd "$REDIS_COMPOSE_DIR"
    docker compose up -d
    sleep 3

    log_info "容器状态:"
    docker compose ps
    echo ""

    # 检查容器是否在运行
    if docker ps --format '{{.Names}}' | grep -q "redis-ha"; then
        log_info "Redis 容器运行中 ✓"
    else
        log_error "Redis 容器未启动！docker compose logs redis"
        exit 1
    fi

    if docker ps --format '{{.Names}}' | grep -q "sentinel-ha"; then
        log_info "Sentinel 容器运行中 ✓"
    else
        log_error "Sentinel 容器未启动！docker compose logs sentinel"
        exit 1
    fi

    # 验证 Redis 连接
    log_info "验证 Redis 连接..."
    if docker exec redis-ha redis-cli -a "$REDIS_PASSWORD" --no-auth-warning PING 2>/dev/null | grep -q PONG; then
        log_info "Redis PING → PONG ✓"
    else
        log_error "Redis 连接失败！docker exec redis-ha redis-cli -a ... PING"
        exit 1
    fi

    # 验证 Redis 角色
    log_info "Redis 角色..."
    ROLE_INFO=$(docker exec redis-ha redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ROLE 2>/dev/null)
    echo "  $ROLE_INFO"

    if [[ "$REDIS_ROLE" == "master" ]]; then
        echo "$ROLE_INFO" | grep -q "master" && log_info "Redis 是 Master ✓" || log_warn "Redis 不是 Master！"
    else
        echo "$ROLE_INFO" | grep -q "slave" && log_info "Redis 是 Slave ✓" || log_warn "Redis 不是 Slave！"
        # 检查主从连接
        LINK=$(docker exec redis-ha redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO replication 2>/dev/null | grep "master_link_status" | cut -d: -f2)
        [ "$LINK" = "up" ] && log_info "主从连接: up ✓" || log_error "主从连接: $LINK — 检查 app10 Redis 是否运行、防火墙是否放行"
    fi

    # 验证 Sentinel
    log_info "验证 Sentinel..."
    if docker exec sentinel-ha redis-cli -p "$SENTINEL_PORT" PING 2>/dev/null | grep -q PONG; then
        log_info "Sentinel PING → PONG ✓"
    else
        log_warn "Sentinel 尚未就绪，等待..."
        sleep 4
        docker exec sentinel-ha redis-cli -p "$SENTINEL_PORT" PING 2>/dev/null | grep -q PONG && log_info "Sentinel 就绪 ✓" || log_warn "Sentinel 可能未正常启动"
    fi

    log_info "Sentinel 监控状态:"
    docker exec sentinel-ha redis-cli -p "$SENTINEL_PORT" SENTINEL MASTER redis-ha 2>/dev/null | grep -E "name|ip|port|flags|num-slaves" || true

    log_info "第四阶段 完成 ✓"
    confirm
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║              第五阶段：上线检查                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

phase5_golive() {
    log_step "第五阶段：上线检查"

    PASS=0; FAIL=0
    check_item() { local d="$1"; shift; if "$@"; then log_info "$d ✓"; ((PASS++)); else log_error "$d ✗"; ((FAIL++)); fi }

    check_item "Nginx 运行"             systemctl is-active --quiet nginx
    check_item "Nginx 语法"             nginx -t &>/dev/null
    check_item "/health 响应"           curl -sf --connect-timeout 2 http://127.0.0.1/health &>/dev/null
    check_item "Keepalived 运行"        systemctl is-active --quiet keepalived
    check_item "Redis 容器运行"          docker ps --format '{{.Names}}' | grep -q redis-ha
    check_item "Sentinel 容器运行"       docker ps --format '{{.Names}}' | grep -q sentinel-ha
    check_item "Redis 密码认证"          docker exec redis-ha redis-cli -a "$REDIS_PASSWORD" --no-auth-warning PING 2>/dev/null | grep -q PONG

    if [ "$ROLE" = "master" ]; then
        check_item "VIP ${VIP} 已绑定"   ip addr show "$INTERFACE" | grep -q "$VIP"
        check_item "Redis 是 Master"     docker exec redis-ha redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ROLE 2>/dev/null | grep -q master
    else
        check_item "Redis 是 Slave"      docker exec redis-ha redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ROLE 2>/dev/null | grep -q slave
    fi

    echo ""
    log_info "结果: $PASS 通过, $FAIL 失败"
    [ "$FAIL" -gt 0 ] && { log_error "有 $FAIL 项失败！"; exit 1; }

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              上 线 状 态 汇 总                            ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    printf "║  主机名:     %-40s ║\n" "$(hostname)"
    printf "║  角色:       %-40s ║\n" "${ROLE^^}"
    printf "║  本机 IP:    %-40s ║\n" "$LOCAL_IP"
    printf "║  VIP:        %-40s ║\n" "$VIP"
    printf "║  Redis:      Docker (redis:7-alpine, host 网络)  ║"
    printf "║  Sentinel:   Docker ${SENTINEL_PORT}              ║"
    echo "╚══════════════════════════════════════════════════════════╝"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  上线!"
    echo ""
    echo "  Nginx 入口:        http://${VIP}"
    echo "  Redis 管理:        docker exec redis-ha redis-cli -a ..."
    echo "  Sentinel 管理:     docker exec sentinel-ha redis-cli -p ${SENTINEL_PORT} ..."
    echo "  Docker Compose 目录: ${REDIS_COMPOSE_DIR}"
    echo ""
    echo "  后端连接 Redis (Sentinel 方式):"
    echo "    Java:  spring.redis.sentinel.nodes=${APP10_IP}:${SENTINEL_PORT},${APP11_IP}:${SENTINEL_PORT}"
    echo "    PHP:   \$sentinels = ['tcp://${APP10_IP}:${SENTINEL_PORT}', ...];"
    echo "    Python: sentinel = Sentinel([('${APP10_IP}', ${SENTINEL_PORT}), ...])"
    echo ""
    echo "  Docker 日常管理:"
    echo "    启动: docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml up -d"
    echo "    停止: docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml down"
    echo "    日志: docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml logs -f"
    echo "    重启: docker compose -f ${REDIS_COMPOSE_DIR}/docker-compose.yml restart"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                               主流程                                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Nginx + Keepalived + Redis(Docker) + Sentinel 高可用部署     ║"
    echo "║  OS: openEuler 24    Docker: redis:7-alpine                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  一 — 环境检查"
    echo "  二 — 软件安装 (Nginx + Keepalived + Docker + Compose)"
    echo "  三 — 配置生成 (Keepalived + Nginx + Docker Compose)"
    echo "  四 — 服务调测 (逐个启动验证)"
    echo "  五 — 上线检查"
    echo ""

    if ! $AUTO_YES; then
        read -r -p ">>> 按回车开始，或 Ctrl+C 退出... "
    fi

    phase1_check
    phase2_install
    phase3_config
    phase4_debug
    phase5_golive
}

main
