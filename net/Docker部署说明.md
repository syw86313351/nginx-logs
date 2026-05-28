# Docker CE 和 Docker Compose 部署说明

## 部署概述

本文档说明如何在 openEuler 系统上安装和配置 Docker CE 和 Docker Compose，数据目录设置为 `/data/docker-data`。

---

## 前置条件

- 操作系统：openEuler（ARM架构）
- 已配置好网络连接
- 具有 root 或 sudo 权限

---

## 步骤1：准备数据目录

```bash
# 创建Docker数据目录
sudo mkdir -p /data/docker-data

# 设置目录权限（可选，根据实际需求调整）
sudo chmod 755 /data/docker-data

# 如果需要特定用户访问，可以设置所有权
# sudo chown -R $USER:$USER /data/docker-data
```

---

## 步骤2：卸载旧版本Docker（如果存在）

```bash
# 检查是否已安装Docker
sudo yum list installed | grep docker

# 如果已安装，卸载旧版本
sudo yum remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine
```

---

## 步骤3：安装必要的工具

```bash
# 更新系统包
sudo yum update -y

# 安装必要的工具
sudo yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2
```

---

## 步骤4：添加Docker官方仓库

### 方法一：使用官方仓库（推荐）

```bash
# 添加Docker官方仓库
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# 如果上述仓库不可用，可以尝试使用阿里云镜像
# sudo yum-config-manager \
#     --add-repo \
#     https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

### 方法二：openEuler系统可能需要使用CentOS兼容仓库

```bash
# 对于openEuler系统，可能需要使用CentOS兼容仓库
sudo yum-config-manager --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

---

## 步骤5：安装Docker CE

```bash
# 安装Docker CE
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 如果遇到依赖问题，可以尝试安装特定版本
# 查看可用版本
# yum list docker-ce --showduplicates | sort -r

# 安装特定版本（例如：docker-ce-20.10.24）
# sudo yum install -y docker-ce-20.10.24 docker-ce-cli-20.10.24 containerd.io
```

---

## 步骤6：配置Docker数据目录

```bash
# 创建Docker配置文件目录
sudo mkdir -p /etc/docker

# 配置Docker使用自定义数据目录
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "/data/docker-data",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
EOF

# 验证配置文件
cat /etc/docker/daemon.json
```

**配置说明**：
- `data-root`: Docker数据根目录，设置为 `/data/docker-data`
- `log-driver`: 日志驱动，使用json-file
- `log-opts`: 日志选项，限制日志大小
- `storage-driver`: 存储驱动，使用overlay2
- `registry-mirrors`: 镜像加速器（可选，提高国内下载速度）

---

## 步骤7：启动Docker服务

```bash
# 启动Docker服务
sudo systemctl start docker

# 设置Docker服务开机自启
sudo systemctl enable docker

# 验证Docker服务状态
sudo systemctl status docker

# 验证Docker安装
sudo docker --version
sudo docker info
```

---

## 步骤8：配置Docker用户组（可选）

```bash
# 创建docker用户组（通常已自动创建）
sudo groupadd docker

# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 重新登录或使用以下命令使组权限生效
newgrp docker

# 验证（不需要sudo）
docker ps
```

---

## 步骤9：安装Docker Compose

### 方法一：使用pip安装（推荐）

```bash
# 安装pip（如果未安装）
sudo yum install -y python3-pip

# 升级pip
sudo pip3 install --upgrade pip

# 安装Docker Compose
sudo pip3 install docker-compose

# 验证安装
docker-compose --version
```

### 方法二：下载二进制文件

```bash
# 下载Docker Compose（ARM架构）
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose

# 或者使用国内镜像
# sudo curl -L "https://get.daocloud.io/docker/compose/releases/download/v2.20.0/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 创建软链接（如果需要）
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 验证安装
docker-compose --version
```

### 方法三：使用yum安装（如果仓库提供）

```bash
# 某些仓库可能提供docker-compose
sudo yum install -y docker-compose
```

---

## 步骤10：验证安装

```bash
# 检查Docker版本
docker --version

# 检查Docker Compose版本
docker-compose --version

# 测试Docker运行
sudo docker run hello-world

# 检查Docker数据目录
sudo ls -lh /data/docker-data

# 检查Docker服务状态
sudo systemctl status docker
```

---

## 步骤11：配置Docker Compose工作目录（可选）

```bash
# 创建Docker Compose项目目录
sudo mkdir -p /data/docker-data/compose

# 设置权限
sudo chmod 755 /data/docker-data/compose

# 如果需要，可以设置环境变量
echo 'export COMPOSE_PROJECT_DIR=/data/docker-data/compose' | sudo tee -a /etc/profile
```

---

## 常用Docker命令

```bash
# 查看Docker信息
docker info

# 查看运行中的容器
docker ps

# 查看所有容器
docker ps -a

# 查看镜像
docker images

# 查看Docker数据使用情况
docker system df

# 清理未使用的数据
docker system prune -a

# 查看Docker日志
sudo journalctl -u docker
```

---

## 常用Docker Compose命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs

# 查看特定服务日志
docker-compose logs -f <service-name>

# 重启服务
docker-compose restart

# 构建并启动
docker-compose up -d --build
```

---

## 故障排查

### 问题1：Docker服务启动失败

```bash
# 查看Docker服务日志
sudo journalctl -u docker -n 50

# 检查配置文件语法
sudo docker daemon --validate

# 检查数据目录权限
ls -ld /data/docker-data
sudo chown -R root:root /data/docker-data
```

### 问题2：无法拉取镜像

```bash
# 检查网络连接
ping registry-1.docker.io

# 测试镜像加速器
docker pull hello-world

# 如果使用镜像加速器，检查配置
cat /etc/docker/daemon.json
```

### 问题3：权限问题

```bash
# 确保用户在docker组中
groups $USER

# 如果不在，添加用户到docker组
sudo usermod -aG docker $USER
newgrp docker
```

### 问题4：数据目录空间不足

```bash
# 检查磁盘空间
df -h /data/docker-data

# 清理Docker数据
docker system prune -a --volumes

# 查看Docker数据使用情况
docker system df
```

---

## 数据目录迁移（如果已安装Docker）

如果Docker已经安装并运行，需要迁移数据目录：

```bash
# 1. 停止Docker服务
sudo systemctl stop docker

# 2. 备份现有数据（如果存在）
sudo cp -r /var/lib/docker /var/lib/docker.backup

# 3. 创建新目录
sudo mkdir -p /data/docker-data

# 4. 移动数据（如果数据量很大，可能需要较长时间）
sudo mv /var/lib/docker/* /data/docker-data/

# 5. 配置daemon.json（见步骤6）

# 6. 启动Docker服务
sudo systemctl start docker

# 7. 验证
docker info | grep "Docker Root Dir"
# 应该显示：/data/docker-data
```

---

## 卸载Docker

如果需要完全卸载Docker：

```bash
# 停止Docker服务
sudo systemctl stop docker

# 卸载Docker包
sudo yum remove -y docker-ce docker-ce-cli containerd.io

# 删除Docker数据（谨慎操作！）
# sudo rm -rf /data/docker-data

# 删除配置文件
sudo rm -rf /etc/docker

# 删除Docker用户组
sudo groupdel docker
```

---

## 配置示例：docker-compose.yml

创建一个简单的docker-compose.yml示例：

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./html:/usr/share/nginx/html
    restart: unless-stopped
    networks:
      - webnet

networks:
  webnet:
    driver: bridge
```

保存为 `docker-compose.yml`，然后运行：

```bash
docker-compose up -d
```

---

## 注意事项

1. **数据目录权限**：确保 `/data/docker-data` 目录有足够的权限
2. **磁盘空间**：Docker会占用较多磁盘空间，确保 `/data` 分区有足够空间
3. **防火墙**：如果使用防火墙，需要开放Docker相关端口
4. **镜像加速**：国内环境建议配置镜像加速器以提高下载速度
5. **定期清理**：定期清理未使用的镜像和容器以节省空间

---

## 参考资源

- Docker官方文档：https://docs.docker.com/
- Docker Compose文档：https://docs.docker.com/compose/
- Docker Hub：https://hub.docker.com/

