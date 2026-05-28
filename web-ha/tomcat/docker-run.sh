#!/bin/bash
# ====================================================================
# Tomcat Docker 部署脚本
# ====================================================================
# 镜像: ectnpmjs.bg-online.com.cn/ect-docker/ect-tomcat9.0.0-jdk11-aarch-redis:2602
# 该镜像已内置 Redisson，无需手动安装 jar 包
# ====================================================================

TOMCAT_IMAGE="ectnpmjs.bg-online.com.cn/ect-docker/ect-tomcat9.0.0-jdk11-aarch-redis:2602"
CONF_DIR="/opt/tomcat-ha/conf"
WEBAPPS_DIR="/opt/tomcat-ha/webapps"

# 创建目录
mkdir -p "$CONF_DIR" "$WEBAPPS_DIR"

# 拉取镜像
docker pull "$TOMCAT_IMAGE"

# 停止旧容器（如果存在）
docker stop tomcat-app 2>/dev/null || true
docker rm tomcat-app 2>/dev/null || true

# 启动
docker run -d \
  --name tomcat-app \
  --network host \
  --restart always \
  -v "$WEBAPPS_DIR:/usr/local/tomcat/webapps" \
  -v "$CONF_DIR/redisson.yaml:/usr/local/tomcat/conf/redisson.yaml" \
  -v "$CONF_DIR/context.xml:/usr/local/tomcat/conf/context.xml" \
  "$TOMCAT_IMAGE"

echo "Tomcat 已启动，查看日志: docker logs -f tomcat-app"
