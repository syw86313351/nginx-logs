# Windows 客户端部署手册

在每台运行 Nginx 的 Windows 主机上，完成以下两步：

## 一、配置 Nginx 输出 JSON 日志

1. 将 `nginx-json-log-format.conf` 中的 `log_format` 片段复制到你的 `nginx.conf` 的 `http {}` 块内。
2. 修改 `"node":"win01"` 为当前主机标识（如 `win02`、`web-prod-01` 等）。
3. 确认 `access_log` 指向你的日志文件路径，例如 `logs/access.log json_analytics;`。
4. 重载 Nginx：

```powershell
cd C:\nginx
nginx -t
nginx -s reload
```

5. 验证 JSON 输出：

```powershell
Invoke-WebRequest http://localhost/ -UseBasicParsing | Out-Null
Get-Content C:\nginx\logs\access.log -Tail 1
```

应该看到一行完整的 JSON。

## 二、安装并配置 Fluent Bit

### 安装

1. 从 https://fluentbit.io/releases/ 下载 Windows 版 zip 包。
2. 解压到 `C:\fluent-bit\`。
3. 创建数据和日志目录：

```powershell
mkdir C:\fluent-bit\data
mkdir C:\fluent-bit\log
```

### 配置

1. 把本目录的以下文件复制到 `C:\fluent-bit\conf\`：

   - `fluent-bit.conf`
   - `parsers.conf`

2. 修改 `fluent-bit.conf` 中的关键配置：

   - `Path` — 改成你的 Nginx 日志路径（如 `C:\nginx\logs\access.log`）
   - `Brokers` — 改成你的**日志服务器 IP:9094**
   - `node` — 改成当前主机标识（如 `win01`、`win02`）

### 启动（测试）

先在命令行前台运行，确认没有报错：

```powershell
cd C:\fluent-bit
.\bin\fluent-bit.exe -c .\conf\fluent-bit.conf
```

看到类似 `[output:kafka:kafka.0] ... connected` 就说明连上了服务端 Kafka。

### 注册为 Windows 服务（长期运行）

```powershell
sc.exe create FluentBit binPath= "C:\fluent-bit\bin\fluent-bit.exe -c C:\fluent-bit\conf\fluent-bit.conf" start= auto
sc.exe start FluentBit
```

查看服务状态：

```powershell
sc.exe query FluentBit
```

停止 / 删除服务（如需卸载）：

```powershell
sc.exe stop FluentBit
sc.exe delete FluentBit
```

## 三、验证端到端

1. 在 Windows 主机上访问 Nginx 产生日志：

```powershell
Invoke-WebRequest http://localhost/ -UseBasicParsing | Out-Null
```

2. 在服务端 Grafana（`http://<服务端IP>:3000`）的 Explore 中查询：

```logql
{job="nginx", host="win01"}
```

能看到这台 Windows 机器的日志即表示整条链路畅通。

## 四、日志清理

Windows 没有 logrotate，可以用计划任务定期清理旧日志：

1. 打开"任务计划程序"。
2. 创建基本任务，每天执行一次。
3. 操作选择"启动程序"，填写：

```
powershell.exe -Command "Get-ChildItem C:\nginx\logs\*.log.* | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force"
```

这样就能保留最近 7 天的归档日志。
