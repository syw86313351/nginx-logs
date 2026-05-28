# web-ha — Nginx + Keepalived + Redis(Docker) + Sentinel + Tomcat 高可用配置集

## 目录结构

```
web-ha/
├── README.md                          ← 本文件
├── nginx/                             ← Nginx 配置
│   ├── upstream.conf                  │   后端 Tomcat 服务器池
│   └── virtual-host.conf              │   反向代理 + 健康检查
├── keepalived/                        ← Keepalived 配置
│   ├── keepalived.conf                │   app10 (MASTER) 用
│   ├── keepalived-backup.conf         │   app11 (BACKUP) 用
│   └── check_nginx.sh                 │   健康检查脚本（两台通用）
├── redis/                             ← Redis Docker Compose
│   ├── docker-compose.yml             │   app10 (Master) 用
│   └── docker-compose-backup.yml      │   app11 (Slave) 用
├── sentinel/                          ← Sentinel 配置
│   └── sentinel.conf                  │   两台通用
├── tomcat/                            ← Tomcat Session 配置
│   ├── redisson.yaml                  │   Redisson 连接配置（Sentinel 模式）
│   └── context.xml                    │   Tomcat Session Manager
├── HA-nginx-setup.sh                  ← 一键部署脚本
└── HA-nginx-README.md                 ← 详细部署文档
```

## 各文件部署位置

| 文件 | 部署到 | 说明 |
|------|--------|------|
| `nginx/upstream.conf` | `/etc/nginx/conf.d/upstream.conf` | app10 + app11 |
| `nginx/virtual-host.conf` | `/etc/nginx/conf.d/virtual-host.conf` | app10 + app11 |
| `keepalived/keepalived.conf` | `/etc/keepalived/keepalived.conf` | app10 用 |
| `keepalived/keepalived-backup.conf` | `/etc/keepalived/keepalived.conf` | app11 用（注意改名） |
| `keepalived/check_nginx.sh` | `/etc/keepalived/check_nginx.sh` | app10 + app11 |
| `redis/docker-compose.yml` | `/opt/redis-ha/docker-compose.yml` | app10 用 |
| `redis/docker-compose-backup.yml` | `/opt/redis-ha/docker-compose.yml` | app11 用（注意改名） |
| `sentinel/sentinel.conf` | `/opt/redis-ha/sentinel.conf` | app10 + app11 |
| `tomcat/redisson.yaml` | `/softs/ect-apps/ROOT/WEB-INF/redisson.yaml` | 每台 Tomcat |
| `tomcat/context.xml` | `META-INF/context.xml` | 每个 Tomcat 应用 |

## 快速部署

### 方式一：一键脚本

```bash
# app10
bash HA-nginx-setup.sh master

# app11
bash HA-nginx-setup.sh backup
```

### 方式二：手动部署

把对应文件复制到目标路径，然后：

```bash
# 启动 Nginx + Keepalived
systemctl restart nginx
systemctl restart keepalived

# 启动 Redis + Sentinel (Docker)
cd /opt/redis-ha
docker compose up -d
```

## 验证

```bash
# 1. Nginx VIP
curl http://10.0.0.30/health    # → OK

# 2. Redis 主从
docker exec redis-ha redis-cli -a cns@2035 --no-auth-warning ROLE
# app10 → master
# app11 → slave, master_link_status:up

# 3. Sentinel
docker exec sentinel-ha redis-cli -p 26379 SENTINEL MASTER redis-ha

# 4. Tomcat Session
# 登录应用 → 查看 Redis 里有 session key
docker exec redis-ha redis-cli -a cns@2035 -n 1 KEYS '*'
```
