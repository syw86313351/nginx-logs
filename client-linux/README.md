# Linux 客户端部署手册

在每台运行 Nginx 的 Linux 主机上，完成以下三步：

## 一、配置 Nginx 输出 JSON 日志

1. 将 `nginx-json-log-format.conf` 中的 `log_format` 片段复制到你的 `nginx.conf` 的 `http {}` 块内。
2. 修改 `"node":"ws01"` 为当前主机标识（如 `ws02`、`web-prod-01` 等）。
3. 确认 `access_log` 指向 `/var/log/nginx/access.log json_analytics;`。
4. 重载 Nginx：

```bash
sudo nginx -t && sudo nginx -s reload
```

5. 验证 JSON 输出：

```bash
curl http://localhost/ >/dev/null 2>&1
tail -1 /var/log/nginx/access.log
```

应该看到一行完整的 JSON。

## 二、安装并配置 Filebeat

### 安装

Debian/Ubuntu：

```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.17.0-amd64.deb
sudo dpkg -i filebeat-8.17.0-amd64.deb
```

CentOS/Rocky：

```bash
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.17.0-x86_64.rpm
sudo rpm -ivh filebeat-8.17.0-x86_64.rpm
```

### 配置

1. 备份原配置：

```bash
sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
```

2. 用本目录的 `filebeat.yml` 替换：

```bash
sudo cp filebeat.yml /etc/filebeat/filebeat.yml
```

3. 修改 `filebeat.yml` 中两处关键配置：

- `paths` — 改成你的 Nginx 日志路径
- `output.kafka.hosts` — 改成你的**日志服务器 IP:9094**
- `fields.node` — 改成当前主机标识

### 启动

```bash
sudo systemctl enable filebeat
sudo systemctl start filebeat
```

### 验证

```bash
sudo filebeat test config
sudo filebeat test output
sudo systemctl status filebeat
```

查看 Filebeat 日志：

```bash
sudo tail -f /var/log/filebeat/filebeat.log
```

## 三、配置日志归档（保留 7 天）

1. 将 `logrotate-nginx` 放到 `/etc/logrotate.d/nginx`：

```bash
sudo cp logrotate-nginx /etc/logrotate.d/nginx
sudo chmod 644 /etc/logrotate.d/nginx
```

2. 检查配置：

```bash
sudo logrotate -d /etc/logrotate.d/nginx
```

3. 手动测试一次：

```bash
sudo logrotate -f /etc/logrotate.d/nginx
ls -lh /var/log/nginx/
```

## 四、验证端到端

1. 在 Linux 主机上访问 Nginx 产生日志：

```bash
curl http://localhost/
```

2. 在服务端 Grafana（`http://<服务端IP>:3000`）的 Explore 中查询：

```logql
{job="nginx", host="ws01"}
```

能看到这台机器的日志即表示整条链路畅通。
