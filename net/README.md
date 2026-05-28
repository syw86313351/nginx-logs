# Linux桥接网络配置文档

## 📚 文档说明

本目录包含Linux桥接网络配置的完整文档和配置文件。

### 主要文档

1. **`nmcli配置命令-快速参考.md`** ⭐ **主文档 - 请先看这个**
   - 完整的桥接网络配置步骤和详细说明
   - 包含两个桥接（qemu-br0和enp132s0f0-br0）的配置
   - 包含所有配置命令、故障排查和工作原理说明
   - 适合首次配置和详细学习

2. **`Docker部署说明.md`** 🐳 **Docker部署文档**
   - Docker CE 和 Docker Compose 安装配置
   - 数据目录配置为 `/data/docker-data`
   - 包含常用命令和故障排查

3. **`配置桥接-nmcli.sh`**
   - 自动化配置脚本（可选使用）
   - 如果不想手动执行命令，可以使用此脚本

---

## 🚀 快速开始

### 推荐配置方式：使用nmcli命令

**配置参数**：
- **qemu-br0**（虚拟机桥接）
  - 物理网口: enp125s0f1
  - IP地址: 192.168.131.101/24
  - 网关: 192.168.131.1
- **enp132s0f0-br0**（NAS桥接，万兆网卡）
  - 物理网口: enp132s0f0
  - IP地址: 10.0.0.3/24
  - 网关: 10.0.0.254

### 核心配置命令（按顺序执行）

```bash
# 1. 检查服务
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager

# 2. 删除旧连接（稳妥方式，逐个删除）
sudo nmcli connection delete qemu-br0 2>/dev/null || echo "qemu-br0不存在"
sudo nmcli connection delete enp125s0f1 2>/dev/null || echo "enp125s0f1不存在"

# 删除残留的桥接接口
sudo ip link set qemu-br0 down 2>/dev/null
sudo brctl delbr qemu-br0 2>/dev/null || sudo ip link delete qemu-br0 2>/dev/null

# 3. 创建桥接接口
sudo nmcli connection add type bridge con-name qemu-br0 ifname qemu-br0 \
    ipv4.addresses 192.168.131.101/24 \
    ipv4.gateway 192.168.131.1 \
    ipv4.dns 192.168.131.1 \
    ipv4.method manual \
    bridge.stp yes \
    connection.autoconnect yes

# 4. 将物理网口添加到桥接
sudo nmcli connection add type ethernet con-name enp125s0f1 \
    ifname enp125s0f1 master qemu-br0 \
    connection.slave-type bridge \
    connection.autoconnect yes

# 5. 激活连接
sudo nmcli connection up enp125s0f1
sudo nmcli connection up qemu-br0

# 6. 验证
ip addr show qemu-br0
brctl show
ping -c 4 192.168.131.1
```

---

## ⚠️ 重要说明

1. **删除的是连接配置，不是物理网卡**
   - 物理网卡 enp125s0f1 是硬件，不会被删除
   - 删除的是 NetworkManager 的连接配置

2. **桥接映射关系**
   - **enp125s0f1**：物理网卡（硬件），不配置IP，作为slave接口
   - **qemu-br0**：桥接接口（虚拟），配置IP地址，作为master接口
   - **enp132s0f0**：物理网卡（硬件），不配置IP，作为slave接口
   - **enp132s0f0-br0**：桥接接口（虚拟），配置IP地址，作为master接口
   - 关系：enp125s0f1 → 绑定到 → qemu-br0，enp132s0f0 → 绑定到 → enp132s0f0-br0
   - 所有网络流量：应用程序 ↔ 桥接接口 ↔ 物理网卡 ↔ 物理网络
   - 详细说明请查看 `nmcli配置命令-快速参考.md` 中的"桥接网络工作原理和映射关系"章节

3. **网络中断风险**
   - 如果当前通过物理网卡进行SSH连接，删除连接会暂时断开网络
   - 建议在本地控制台操作，或确保有其他网口保持连接

4. **详细步骤和故障排查**
   - 请查看 `nmcli配置命令-快速参考.md` 获取完整的配置步骤和故障排查方法

---

## 📖 文档导航

- **网络桥接配置** → 查看 `nmcli配置命令-快速参考.md` ⭐
- **Docker部署** → 查看 `Docker部署说明.md`
- **自动化配置** → 使用 `配置桥接-nmcli.sh` 脚本

---

## 🔧 配置完成后验证

配置成功后，应满足以下条件：

- [ ] `ip addr show qemu-br0` 显示IP地址 192.168.131.101/24
- [ ] `ip addr show enp132s0f0-br0` 显示IP地址 10.0.0.3/24
- [ ] `brctl show` 显示qemu-br0包含enp125s0f1，enp132s0f0-br0包含enp132s0f0
- [ ] `nmcli connection show` 显示所有桥接和slave接口状态为已连接
- [ ] `ping 192.168.131.1` 可以ping通qemu-br0网关
- [ ] `ping 10.0.0.254` 可以ping通enp132s0f0-br0网关

---

## ❗ 常见问题

### 虚拟机使用桥接网络不通

**如果虚拟机无法访问网络，请立即检查以下配置：**

```bash
# 1. 配置sysctl允许桥接流量通过iptables（关键！）
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl -w net.ipv4.ip_forward=1

# 永久保存
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 2. 配置iptables，允许桥接流量转发
sudo iptables -I FORWARD -i qemu-br0 -j ACCEPT
sudo iptables -I FORWARD -o qemu-br0 -j ACCEPT
sudo iptables -I FORWARD -i enp132s0f0-br0 -j ACCEPT
sudo iptables -I FORWARD -o enp132s0f0-br0 -j ACCEPT
```

**详细排查步骤请查看 `nmcli配置命令-快速参考.md` 中的"问题5：虚拟机使用桥接网络不通"章节**

