# Linux桥接网络配置完整指南

## 推荐方案：使用nmcli命令配置（最可靠）

本方案使用NetworkManager的nmcli命令行工具，适用于openEuler系统，配置简单可靠，支持开机自动启动。

## 桥接配置说明

本系统配置了两个桥接网络：

1. **qemu-br0** - 虚拟机桥接
   - 物理网卡：enp125s0f1
   - IP地址：192.168.131.101/24
   - 网关：192.168.131.1

2. **enp132s0f0-br0** - NAS桥接（万兆网卡）
   - 物理网卡：enp132s0f0
   - IP地址：10.0.0.3/24
   - 网关：10.0.0.254

---

## 步骤1：检查前置条件

```bash
# 1.1 检查NetworkManager服务状态
sudo systemctl status NetworkManager

# 如果服务未运行，启动并启用
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager

# 1.2 检查物理网口是否存在
ip link show enp125s0f1
ip link show enp132s0f0

# 1.3 检查是否已安装bridge-utils（可选，用于查看桥接信息）
rpm -q bridge-utils || sudo yum install -y bridge-utils

# 1.4 加载桥接内核模块（如果未加载）
# 注意：bridge模块通常在创建桥接时会自动加载，但为了确保重启后也能正常工作，建议配置自动加载
sudo modprobe bridge
sudo modprobe br_netfilter

# 配置开机自动加载内核模块（可选，但推荐）
echo "bridge" | sudo tee /etc/modules-load.d/bridge.conf
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/bridge.conf

# 验证模块是否已加载
lsmod | grep bridge
```

---

## 步骤2：查看现有连接（备份信息）

```bash
# 查看当前所有网络连接
sudo nmcli connection show

# 查找桥接相关的连接
sudo nmcli connection show | grep -E "qemu-br0|enp132s0f0-br0|enp125s0f1|enp132s0f0"

# 查看当前活动的连接
sudo nmcli connection show --active

# 检查接口当前使用的连接
CURRENT_CONN1=$(nmcli -t -f NAME,DEVICE connection show --active | grep "enp125s0f1" | cut -d: -f1)
if [ -n "$CURRENT_CONN1" ]; then
    echo "警告: enp125s0f1当前使用的连接: $CURRENT_CONN1"
    echo "删除此连接可能会断开当前网络，请确保有其他方式访问系统"
fi

CURRENT_CONN2=$(nmcli -t -f NAME,DEVICE connection show --active | grep "enp132s0f0" | cut -d: -f1)
if [ -n "$CURRENT_CONN2" ]; then
    echo "警告: enp132s0f0当前使用的连接: $CURRENT_CONN2"
    echo "删除此连接可能会断开当前网络，请确保有其他方式访问系统"
fi

# 检查当前存在的桥接接口
echo ""
echo "当前桥接接口:"
brctl show 2>/dev/null || echo "未找到桥接接口或bridge-utils未安装"
if command -v brctl &> /dev/null; then
    BRIDGES=$(brctl show 2>/dev/null | awk 'NR>1 {print $1}')
    if [ -n "$BRIDGES" ]; then
        echo "发现以下桥接接口，将在步骤3中删除: $BRIDGES"
    fi
fi
```

---

## 步骤3：删除现有连接（如果存在）

**重要说明**：
- 这里删除的是 **NetworkManager的连接配置**，**不是物理网卡本身**
- 物理网卡是硬件，不会被删除
- 如果物理网卡已有独立的连接配置（如直接配置了IP地址），需要删除该配置
- 删除后，我们会在后续步骤中重新创建连接，将其配置为桥接的slave接口

### 删除qemu-br0相关连接

```bash
# 删除已知的连接配置（稳妥方式，逐个删除）
sudo nmcli connection delete qemu-br0 2>/dev/null || echo "qemu-br0不存在，跳过"
sudo nmcli connection delete enp125s0f1 2>/dev/null || echo "enp125s0f1连接配置不存在，跳过（物理网卡仍然存在）"

# 删除残留的桥接接口（稳妥方式，逐个删除）
sudo ip link set qemu-br0 down 2>/dev/null
sudo brctl delbr qemu-br0 2>/dev/null || sudo ip link delete qemu-br0 2>/dev/null || echo "qemu-br0桥接接口不存在，跳过"

# 检查是否有系统自动生成的连接（需要手动处理）
sudo nmcli connection show | grep enp125s0f1
# 如果看到其他连接名称（如 "System enp125s0f1" 或类似），手动删除：
# sudo nmcli connection delete "连接名称" 2>/dev/null
```

### 删除enp132s0f0-br0相关连接

```bash
# 删除已知的连接配置（稳妥方式，逐个删除）
sudo nmcli connection delete enp132s0f0-br0 2>/dev/null || echo "enp132s0f0-br0不存在，跳过"
sudo nmcli connection delete enp132s0f0 2>/dev/null || echo "enp132s0f0连接配置不存在，跳过（物理网卡仍然存在）"

# 删除残留的桥接接口（稳妥方式，逐个删除）
sudo ip link set enp132s0f0-br0 down 2>/dev/null
sudo brctl delbr enp132s0f0-br0 2>/dev/null || sudo ip link delete enp132s0f0-br0 2>/dev/null || echo "enp132s0f0-br0桥接接口不存在，跳过"

# 检查是否有系统自动生成的连接（需要手动处理）
sudo nmcli connection show | grep enp132s0f0
# 如果看到其他连接名称，手动删除
```

### 等待并验证删除结果

```bash
# 等待连接和接口完全断开
sleep 2

# 验证删除结果
echo ""
echo "当前剩余连接:"
sudo nmcli connection show | grep -E "qemu-br0|enp132s0f0-br0|enp125s0f1|enp132s0f0" || echo "未找到相关连接，可以继续配置"

echo ""
echo "当前桥接接口:"
brctl show 2>/dev/null || echo "未找到桥接接口，可以继续配置"
```

**注意事项**：
- **物理网卡不会被删除**：删除的是NetworkManager的连接配置，物理网卡是硬件，不会被删除
- **为什么要删除连接配置**：
  - 如果物理网卡已有独立连接（直接配置了IP），需要删除以便将其加入桥接
  - 如果物理网卡已是其他桥接的slave，需要删除旧配置后重新配置
- **网络中断风险**：如果当前通过该网卡进行SSH连接，删除连接配置会暂时断开网络
- **建议**：在本地控制台操作，或确保有其他网口保持连接

---

## 步骤4：创建桥接接口

### 创建qemu-br0桥接

```bash
sudo nmcli connection add type bridge \
    con-name qemu-br0 \
    ifname qemu-br0 \
    ipv4.addresses 192.168.131.101/24 \
    ipv4.gateway 192.168.131.1 \
    ipv4.dns 192.168.131.1 \
    ipv4.method manual \
    bridge.stp yes \
    connection.autoconnect yes
```

**命令说明**：
- `type bridge`: 创建桥接类型连接
- `con-name qemu-br0`: 连接名称
- `ifname qemu-br0`: 接口名称
- `ipv4.addresses`: IP地址和子网掩码
- `ipv4.gateway`: 默认网关
- `ipv4.dns`: DNS服务器
- `ipv4.method manual`: 手动配置IP（静态）
- `bridge.stp yes`: 启用生成树协议（防止环路）
- `connection.autoconnect yes`: 开机自动连接

### 创建enp132s0f0-br0桥接

```bash
# enp132s0f0-br0配置（万兆网卡）
sudo nmcli connection add type bridge \
    con-name enp132s0f0-br0 \
    ifname enp132s0f0-br0 \
    ipv4.addresses 10.0.0.3/24 \
    ipv4.gateway 10.0.0.254 \
    ipv4.dns 10.0.0.254 \
    ipv4.method manual \
    bridge.stp yes \
    connection.autoconnect yes
```

---

## 步骤5：将物理网口添加到桥接（配置slave接口）

**说明**：这一步会为物理网卡创建一个新的连接配置，将其配置为桥接的slave接口。物理网卡本身不会被删除或修改，只是网络配置方式改变了。

### 添加enp125s0f1到qemu-br0

```bash
sudo nmcli connection add type ethernet \
    con-name enp125s0f1 \
    ifname enp125s0f1 \
    master qemu-br0 \
    connection.slave-type bridge \
    connection.autoconnect yes
```

### 添加enp132s0f0到enp132s0f0-br0

```bash
sudo nmcli connection add type ethernet \
    con-name enp132s0f0 \
    ifname enp132s0f0 \
    master enp132s0f0-br0 \
    connection.slave-type bridge \
    connection.autoconnect yes
```

**命令说明**：
- `type ethernet`: 以太网类型
- `con-name`: 连接名称
- `ifname`: 物理接口名称
- `master`: 指定主接口（桥接），使此接口成为桥接的slave（从属接口）
- `connection.slave-type bridge`: 明确指定slave类型为bridge（可选，但推荐）
- `connection.autoconnect yes`: 开机自动连接

**重要说明**：
- slave接口（物理网口）**不需要配置IP地址**，IP地址由桥接接口（master）管理
- slave接口通过 `master` 参数自动成为桥接的从属接口
- 所有网络流量将通过桥接接口进行路由

---

## 步骤6：激活连接

```bash
# 激活qemu-br0相关连接
sudo nmcli connection up enp125s0f1
sudo nmcli connection up qemu-br0

# 激活enp132s0f0-br0相关连接
sudo nmcli connection up enp132s0f0
sudo nmcli connection up enp132s0f0-br0
```

---

## 步骤7：配置sysctl参数（虚拟机桥接必需）

**说明**：如果需要在虚拟机中使用桥接网络，必须配置以下sysctl参数，否则虚拟机将无法访问网络。

```bash
# 7.1 加载br_netfilter模块（如果未加载）
sudo modprobe br_netfilter

# 7.2 检查是否已配置（避免重复写入）
if ! grep -q "net.bridge.bridge-nf-call-iptables" /etc/sysctl.conf; then
    # 配置sysctl参数（永久生效）
    # 允许桥接流量通过iptables
    echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-arptables = 1" | sudo tee -a /etc/sysctl.conf
    
    # 启用IP转发
    echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
    
    # 立即生效
    sudo sysctl -p
else
    echo "sysctl配置已存在，跳过写入"
    # 确保配置生效
    sudo sysctl -p
fi

# 7.3 验证配置
cat /proc/sys/net/bridge/bridge-nf-call-iptables
cat /proc/sys/net/ipv4/ip_forward
# 应该都显示：1
```

**注意**：
- 这些配置在系统重启后会自动生效
- 如果不需要虚拟机桥接功能，可以跳过此步骤
- 脚本会自动检查避免重复写入配置

---

## 步骤8：验证配置

```bash
# 8.1 检查桥接接口状态和IP地址
ip addr show qemu-br0
ip addr show enp132s0f0-br0

# 应该看到类似输出：
# inet 192.168.131.101/24 brd 192.168.131.255 scope global qemu-br0
# inet 10.0.0.3/24 brd 10.0.0.255 scope global enp132s0f0-br0

# 8.2 检查桥接成员（验证slave接口）
brctl show

# 应该看到qemu-br0包含enp125s0f1，enp132s0f0-br0包含enp132s0f0

# 8.3 检查slave接口配置
sudo nmcli connection show enp125s0f1 | grep -E "master|slave-type"
sudo nmcli connection show enp132s0f0 | grep -E "master|slave-type"

# 应该看到：
# connection.master: qemu-br0 / enp132s0f0-br0
# connection.slave-type: bridge

# 8.4 检查网络连接状态
sudo nmcli connection show

# 应该看到所有桥接和slave接口都是已连接状态

# 8.5 检查路由表
ip route show

# 应该看到默认路由通过相应的桥接接口

# 8.6 测试网络连通性
ping -c 4 192.168.131.1  # qemu-br0网关
ping -c 4 10.0.0.254  # enp132s0f0-br0网关

# 8.7 检查DNS解析
ping -c 2 www.baidu.com
```

---

## 配置验证清单

配置成功后，应满足以下条件：

- [ ] `ip addr show qemu-br0` 显示IP地址 192.168.131.101/24
- [ ] `ip addr show enp132s0f0-br0` 显示IP地址 10.0.0.3/24
- [ ] `brctl show` 显示qemu-br0包含enp125s0f1，enp132s0f0-br0包含enp132s0f0
- [ ] `nmcli connection show` 显示所有桥接和slave接口状态为已连接
- [ ] `ip route show` 显示默认网关通过相应的桥接接口
- [ ] `ping 192.168.131.1` 可以ping通qemu-br0网关
- [ ] `ping 10.0.0.254` 可以ping通enp132s0f0-br0网关
- [ ] 可以访问外网（如果网关支持）

---

## 常用检查命令

```bash
# 查看所有连接
sudo nmcli connection show

# 查看活动连接
sudo nmcli connection show --active

# 查找特定接口的连接
sudo nmcli connection show | grep enp125s0f1
sudo nmcli connection show | grep enp132s0f0

# 查看连接详情
sudo nmcli connection show qemu-br0
sudo nmcli connection show enp132s0f0-br0

# 查看slave接口配置
sudo nmcli connection show enp125s0f1 | grep -E "master|slave-type"
sudo nmcli connection show enp132s0f0 | grep -E "master|slave-type"

# 查看接口状态
ip addr show qemu-br0
ip addr show enp132s0f0-br0
ip link show qemu-br0
ip link show enp132s0f0-br0

# 查看所有桥接成员（验证slave接口）
brctl show

# 查看路由
ip route show

# 测试连通性
ping -c 4 192.168.131.1  # qemu-br0网关
ping -c 4 10.0.0.254  # enp132s0f0-br0网关
```

---

## 常用修改命令

### 修改qemu-br0配置

```bash
# 修改IP地址
sudo nmcli connection modify qemu-br0 ipv4.addresses 192.168.131.20/24
sudo nmcli connection down qemu-br0 && sudo nmcli connection up qemu-br0

# 修改网关
sudo nmcli connection modify qemu-br0 ipv4.gateway 192.168.131.2
sudo nmcli connection down qemu-br0 && sudo nmcli connection up qemu-br0

# 修改DNS
sudo nmcli connection modify qemu-br0 ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli connection down qemu-br0 && sudo nmcli connection up qemu-br0

# 禁用STP
sudo nmcli connection modify qemu-br0 bridge.stp no
sudo nmcli connection down qemu-br0 && sudo nmcli connection up qemu-br0
```

### 修改enp132s0f0-br0配置

```bash
# 修改IP地址
sudo nmcli connection modify enp132s0f0-br0 ipv4.addresses 10.0.0.20/24
sudo nmcli connection down enp132s0f0-br0 && sudo nmcli connection up enp132s0f0-br0

# 修改网关
sudo nmcli connection modify enp132s0f0-br0 ipv4.gateway 10.0.0.254
sudo nmcli connection down enp132s0f0-br0 && sudo nmcli connection up enp132s0f0-br0

# 修改DNS
sudo nmcli connection modify enp132s0f0-br0 ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli connection down enp132s0f0-br0 && sudo nmcli connection up enp132s0f0-br0

# 禁用STP
sudo nmcli connection modify enp132s0f0-br0 bridge.stp no
sudo nmcli connection down enp132s0f0-br0 && sudo nmcli connection up enp132s0f0-br0
```

---

## 删除配置

### 删除qemu-br0配置

```bash
# 删除NetworkManager连接
sudo nmcli connection down qemu-br0
sudo nmcli connection down enp125s0f1
sudo nmcli connection delete qemu-br0
sudo nmcli connection delete enp125s0f1

# 删除桥接接口（重要！删除连接后桥接接口可能仍然存在）
sudo ip link set qemu-br0 down 2>/dev/null
sudo brctl delbr qemu-br0 2>/dev/null || sudo ip link delete qemu-br0 2>/dev/null
```

### 删除enp132s0f0-br0配置

```bash
# 删除NetworkManager连接
sudo nmcli connection down enp132s0f0-br0
sudo nmcli connection down enp132s0f0
sudo nmcli connection delete enp132s0f0-br0
sudo nmcli connection delete enp132s0f0

# 删除桥接接口（重要！删除连接后桥接接口可能仍然存在）
sudo ip link set enp132s0f0-br0 down 2>/dev/null
sudo brctl delbr enp132s0f0-br0 2>/dev/null || sudo ip link delete enp132s0f0-br0 2>/dev/null
```

---

## 桥接网络工作原理和映射关系

### 桥接映射关系

**简单理解**：
- **物理网卡**：硬件接口，负责实际的物理连接
- **桥接接口**：虚拟接口，作为网络层的工作接口

**映射关系**：
```
物理网卡 (enp125s0f1)  ←→  桥接接口 (qemu-br0)  ←→  虚拟机/主机应用
物理网卡 (enp132s0f0)  ←→  桥接接口 (enp132s0f0-br0)   ←→  NAS/主机应用
    [硬件层]              [网络层]              [应用层]
```

### 详细工作原理

1. **物理网卡**
   - 这是真实的硬件网卡
   - 连接到物理网络（网线）
   - **不配置IP地址**（作为slave接口）
   - 只负责接收和发送物理数据包

2. **桥接接口**
   - 这是虚拟的网络接口（软件层面）
   - **配置IP地址**和网络参数
   - 管理网络配置（网关、DNS等）
   - 作为网络通信的入口和出口

3. **映射关系**
   - 物理网卡通过 `master` 参数绑定到桥接
   - 所有通过物理网卡的流量都会经过桥接接口
   - 桥接接口负责处理网络协议栈（IP、路由等）
   - 物理网卡只负责物理层的数据传输

### 数据流向

**主机发送数据**：
```
应用程序 → 桥接接口 (处理IP/路由) → 物理网卡 (物理发送) → 网络
```

**主机接收数据**：
```
网络 → 物理网卡 (物理接收) → 桥接接口 (处理IP/路由) → 应用程序
```

**虚拟机/NAS通信**：
```
虚拟机/NAS → 桥接接口 (桥接转发) → 物理网卡 (物理发送) → 网络
网络 → 物理网卡 (物理接收) → 桥接接口 (桥接转发) → 虚拟机/NAS
```

### 查看映射关系

```bash
# 查看桥接成员（显示哪些接口属于桥接）
brctl show

# 输出示例：
# bridge name     bridge id               STP enabled     interfaces
# qemu-br0        8000.xxxxxxxxxxxx       yes             enp125s0f1
#                                                         vnet0
#                                                         vnet1
# enp132s0f0-br0         8000.yyyyyyyyyyyy       yes             enp132s0f0
# 
# 说明：enp125s0f1、vnet0、vnet1 都是 qemu-br0 的成员
#      enp132s0f0 是 enp132s0f0-br0 的成员

# 查看物理网卡的桥接绑定关系
ip link show enp125s0f1
ip link show enp132s0f0
# 应该看到：master qemu-br0 / master enp132s0f0-br0

# 查看NetworkManager连接配置
sudo nmcli connection show enp125s0f1 | grep master
sudo nmcli connection show enp132s0f0 | grep master
# 应该显示：connection.master: qemu-br0 / enp132s0f0-br0

# 查看所有桥接接口的详细信息
bridge link show
```

### 关键点总结

1. **物理网卡是slave（从属）**：
   - 不配置IP地址
   - 通过 `master` 参数绑定到桥接
   - 只负责物理层数据传输

2. **桥接接口是master（主接口）**：
   - 配置IP地址和网络参数
   - 管理所有网络配置
   - 处理网络协议栈

3. **一对多关系**：
   - 一个桥接接口可以包含多个成员
   - 物理网卡
   - 虚拟机虚拟网卡（vnet0、vnet1等）
   - 所有成员共享同一个网络段

4. **当前配置的桥接映射关系**：
   - **qemu-br0** ← **enp125s0f1**（虚拟机桥接）
   - **enp132s0f0-br0** ← **enp132s0f0**（NAS桥接）

---

## 故障排查

### 问题1：桥接接口未创建

**检查项**：
```bash
# 检查NetworkManager服务
sudo systemctl status NetworkManager

# 检查内核模块
lsmod | grep bridge

# 如果模块未加载，手动加载
sudo modprobe bridge
sudo modprobe br_netfilter

# 注意：bridge模块通常在创建桥接时会自动加载
# 如果重启后模块未自动加载，配置开机自动加载：
echo "bridge" | sudo tee /etc/modules-load.d/bridge.conf
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/bridge.conf
```

### 问题2：无法ping通网关

**检查项**：
```bash
# 检查IP地址是否正确配置
ip addr show qemu-br0
ip addr show enp132s0f0-br0

# 检查路由
ip route show

# 检查物理网口是否在桥接中
brctl show

# 检查防火墙（检查iptables状态）
sudo systemctl status iptables
```

### 问题3：重启后配置丢失

**检查项**：
```bash
# 确认autoconnect已启用
sudo nmcli connection show qemu-br0 | grep autoconnect
sudo nmcli connection show enp132s0f0-br0 | grep autoconnect

# 应该显示：connection.autoconnect: yes

# 如果未启用，执行：
sudo nmcli connection modify qemu-br0 connection.autoconnect yes
sudo nmcli connection modify enp132s0f0-br0 connection.autoconnect yes
```

### 问题4：网络连接中断

如果配置过程中网络中断：

```bash
# 在本地控制台或通过其他网口连接后，检查状态
sudo nmcli connection show

# 如果连接未激活，手动激活
sudo nmcli connection up qemu-br0
sudo nmcli connection up enp125s0f1
sudo nmcli connection up enp132s0f0-br0
sudo nmcli connection up enp132s0f0
```

### 问题5：虚拟机使用桥接网络不通（重要！）

**现象**：桥接配置完成，主机网络正常，但虚拟机无法访问网络

**常见原因和解决方法**：

#### 5.1 检查桥接接口和物理网口状态

```bash
# 检查桥接接口状态
ip addr show qemu-br0
ip addr show enp132s0f0-br0

# 检查桥接成员
brctl show

# 检查物理网口状态
ip link show enp125s0f1
ip link show enp132s0f0

# 如果物理网口未UP，激活它
sudo ip link set enp125s0f1 up
sudo ip link set enp132s0f0 up
```

#### 5.2 检查并配置防火墙规则（最常见原因）

```bash
# 检查iptables状态
sudo systemctl status iptables

# 检查iptables规则
sudo iptables -L -n -v | grep -E "qemu-br0|enp132s0f0-br0"
```

#### 5.3 检查sysctl配置

```bash
# 检查sysctl配置是否正确
cat /proc/sys/net/bridge/bridge-nf-call-iptables
cat /proc/sys/net/ipv4/ip_forward
# 应该都显示：1

# 如果显示0，请参考"步骤7：配置sysctl参数"进行配置
```

#### 5.5 配置iptables规则允许桥接流量转发

```bash
# 允许桥接接口的流量转发
sudo iptables -I FORWARD -i qemu-br0 -j ACCEPT
sudo iptables -I FORWARD -o qemu-br0 -j ACCEPT
sudo iptables -I FORWARD -i enp132s0f0-br0 -j ACCEPT
sudo iptables -I FORWARD -o enp132s0f0-br0 -j ACCEPT

# 允许NAT转发（如果虚拟机需要访问外网）
sudo iptables -t nat -A POSTROUTING -s 192.168.131.0/24 ! -d 192.168.131.0/24 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 ! -d 10.0.0.0/24 -j MASQUERADE

# 保存iptables规则
sudo iptables-save > /etc/sysconfig/iptables
```

#### 5.6 检查虚拟机网络配置

```bash
# 如果使用QEMU/KVM，检查虚拟机网络配置
# 虚拟机应该配置为使用桥接网络，桥接名称应该是 qemu-br0

# 使用virsh的虚拟机，检查网络配置
virsh domiflist <虚拟机名称>
# 应该看到网络类型为bridge，源为qemu-br0

# 使用qemu命令的虚拟机，确保使用：
# -netdev bridge,id=net0,br=qemu-br0
# 或
# -net bridge,br=qemu-br0
```

#### 5.7 完整排查步骤（按顺序执行）

```bash
# 1. 检查桥接配置
ip addr show qemu-br0
ip addr show enp132s0f0-br0
brctl show

# 2. 检查iptables防火墙
sudo systemctl status iptables
# 检查iptables规则是否允许桥接流量转发

# 3. 检查sysctl配置（如果未配置，请参考"步骤7：配置sysctl参数"）
cat /proc/sys/net/bridge/bridge-nf-call-iptables
cat /proc/sys/net/ipv4/ip_forward

# 4. 检查iptables规则
sudo iptables -L -n -v | grep -E "qemu-br0|enp132s0f0-br0"

# 5. 测试主机到网关连通性
ping -c 4 192.168.131.1
ping -c 4 10.0.0.254

# 6. 在虚拟机内测试
# ping 192.168.131.1（网关）
# ping 192.168.131.101（主机桥接IP）
```

#### 5.8 一键修复脚本（如果上述步骤都正常但仍不通）

```bash
# 1. 确保sysctl配置正确（参考"步骤7：配置sysctl参数"）
cat /proc/sys/net/bridge/bridge-nf-call-iptables
cat /proc/sys/net/ipv4/ip_forward

# 配置iptables规则
sudo iptables -I FORWARD -i qemu-br0 -j ACCEPT
sudo iptables -I FORWARD -o qemu-br0 -j ACCEPT
sudo iptables -I FORWARD -i enp132s0f0-br0 -j ACCEPT
sudo iptables -I FORWARD -o enp132s0f0-br0 -j ACCEPT
```

---

## 配置详情

### 桥接接口 (qemu-br0)
- IP地址: 192.168.131.101/24
- 网关: 192.168.131.1
- STP: 启用（防止环路）
- 开机自动启动: 是
- **作用**：网络层接口，管理IP配置和路由

### 物理网口 (enp125s0f1)
- 类型: 以太网
- 桥接绑定: qemu-br0（作为slave接口）
- 开机自动启动: 是
- **作用**：物理层接口，负责实际的数据传输
- **注意**：不配置IP地址，由桥接接口管理

### 桥接接口 (enp132s0f0-br0)
- IP地址: 10.0.0.3/24
- 网关: 10.0.0.254
- STP: 启用（防止环路）
- 开机自动启动: 是
- **作用**：网络层接口，管理IP配置和路由

### 物理网口 (enp132s0f0)
- 类型: 以太网
- 桥接绑定: enp132s0f0-br0（作为slave接口）
- 开机自动启动: 是
- **作用**：物理层接口，负责实际的数据传输
- **注意**：不配置IP地址，由桥接接口管理

---

## 注意事项

1. **远程操作风险**：如果当前通过物理网卡进行SSH连接，配置后连接可能会中断。建议：
   - 在本地控制台操作
   - 或使用IPMI/iKVM等带外管理
   - 或配置多个网口，确保至少一个网口保持连接

2. **服务检查**：确保NetworkManager服务已启用
   ```bash
   sudo systemctl enable NetworkManager
   sudo systemctl status NetworkManager
   ```

3. **防火墙**：如果启用了防火墙，可能需要相应调整规则

4. **DNS配置**：如需自定义DNS，可在nmcli命令中添加：
   ```bash
   sudo nmcli connection modify qemu-br0 ipv4.dns "8.8.8.8 8.8.4.4"
   sudo nmcli connection modify enp132s0f0-br0 ipv4.dns "8.8.8.8 8.8.4.4"
   ```

5. **enp132s0f0-br0配置**：enp132s0f0-br0使用万兆网卡enp132s0f0，IP地址为10.0.0.3/24，网关为10.0.0.254。
