# ============================================================
#  Vector Agent Windows 一键安装脚本
#  以管理员身份运行 PowerShell:
#    .\install.ps1 -KafkaBrokers "192.168.1.100:9093" -NodeName "ws01" -NginxLogPath "C:\nginx\logs\access.log"
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$KafkaBrokers,

    [Parameter(Mandatory=$true)]
    [string]$NodeName,

    [string]$NginxLogPath    = 'C:\nginx\logs\access.log',
    [string]$VectorVersion   = "0.39.0",
    [string]$InstallDir      = 'C:\vector'
)

$ErrorActionPreference = "Stop"
$ServiceName = "vector"
$ZipUrl      = "https://packages.timber.io/vector/$VectorVersion/vector-$VectorVersion-x86_64-pc-windows-msvc.zip"
$ZipPath     = "$env:TEMP\vector.zip"

Write-Host "=== Vector Agent $VectorVersion Windows 安装 ===" -ForegroundColor Cyan
Write-Host "  Kafka : $KafkaBrokers"
Write-Host "  节点  : $NodeName"
Write-Host "  日志  : $NginxLogPath"

# ── 1. 停止旧服务 ────────────────────────────────────────────
$old = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($old) {
    Write-Host "[1/5] 停止旧服务..." -ForegroundColor Yellow
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep 2
}

# ── 2. 下载 Vector ───────────────────────────────────────────
Write-Host "[2/5] 下载 Vector $VectorVersion ..." -ForegroundColor Yellow
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
New-Item -ItemType Directory -Path "$InstallDir\data" -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP\vector-extract" -Force
$extracted = Get-ChildItem "$env:TEMP\vector-extract" -Recurse -Filter "vector.exe" | Select-Object -First 1
Copy-Item $extracted.FullName "$InstallDir\vector.exe" -Force
Remove-Item "$env:TEMP\vector-extract" -Recurse -Force

# ── 3. 写入配置 ──────────────────────────────────────────────
Write-Host "[3/5] 写入配置文件..." -ForegroundColor Yellow
$logPathFixed = $NginxLogPath -replace '\\', '\\\\'
$config = @"
[sources.nginx_log]
type = "file"
include = ["$logPathFixed"]
read_from = "end"
ignore_older_secs = 86400
data_dir = "C:/vector/data"

[transforms.add_meta]
type = "remap"
inputs = ["nginx_log"]
source = '''
.agent_host = "$NodeName"
.collected_at = now()
'''

[sinks.kafka_out]
type = "kafka"
inputs = ["add_meta"]
bootstrap_servers = "$KafkaBrokers"
topic = "nginx-logs"
key_field = "agent_host"
compression = "lz4"

[sinks.kafka_out.encoding]
codec = "json"

[sinks.kafka_out.batch]
max_bytes = 1048576
timeout_secs = 2

[sinks.kafka_out.request]
concurrency = 2
"@
$config | Set-Content "$InstallDir\vector.toml" -Encoding UTF8

# ── 4. 注册 Windows 服务 ─────────────────────────────────────
Write-Host "[4/5] 注册 Windows 服务..." -ForegroundColor Yellow
$binPath = "`"$InstallDir\vector.exe`" --config `"$InstallDir\vector.toml`""
sc.exe create $ServiceName binPath= $binPath start= auto DisplayName= "Vector Log Agent" | Out-Null
sc.exe description $ServiceName "Tails nginx JSON logs and pushes to Kafka" | Out-Null

# ── 5. 启动服务 ──────────────────────────────────────────────
Write-Host "[5/5] 启动服务..." -ForegroundColor Yellow
Start-Service $ServiceName
Start-Sleep 3

$svc = Get-Service -Name $ServiceName
if ($svc.Status -eq "Running") {
    Write-Host ""
    Write-Host "  Vector Agent 运行中" -ForegroundColor Green
    Write-Host "  配置: $InstallDir\vector.toml"
    Write-Host "  位点: $InstallDir\data"
    Write-Host ""
    Write-Host "验证推送（在 Kafka UI 中查看 topic nginx-logs 消息数）:" -ForegroundColor Cyan
    Write-Host "  http://SERVER_IP:8080"
    Write-Host ""
    Write-Host "常用命令:"
    Write-Host "  Get-Service vector          # 查看状态"
    Write-Host "  Stop-Service vector         # 停止"
    Write-Host "  sc.exe delete vector        # 卸载"
} else {
    Write-Host "  服务状态异常: $($svc.Status)" -ForegroundColor Red
    Write-Host "  手动运行调试: $InstallDir\vector.exe --config $InstallDir\vector.toml" -ForegroundColor Yellow
    exit 1
}
