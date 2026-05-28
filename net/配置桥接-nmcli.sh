#!/bin/bash
# Linux桥接网络配置脚本 - 使用nmcli方式
# 适用于openEuler系统

set -e

echo "=========================================="
echo "Linux桥接网络配置脚本"
echo "=========================================="

# 配置参数
BRIDGE_NAME="enp132s0f0-br0"
PHYSICAL_IF="enp132s0f0"
IP_ADDR="10.0.0.3/24"
GATEWAY="10.0.0.254"
DNS="10.0.0.254"

echo "桥接名称: $BRIDGE_NAME"
echo "物理网口: $PHYSICAL_IF"
echo "IP地址: $IP_ADDR"
echo "网关: $GATEWAY"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "错误: 请使用sudo运行此脚本"
    exit 1
fi

# 检查NetworkManager服务
if ! systemctl is-active --quiet NetworkManager; then
    echo "启动NetworkManager服务..."
    systemctl start NetworkManager
    systemctl enable NetworkManager
fi

# 检查物理网口是否存在
if ! ip link show "$PHYSICAL_IF" &>/dev/null; then
    echo "错误: 物理网口 $PHYSICAL_IF 不存在"
    exit 1
fi

# 安装桥接工具
if ! command -v brctl &> /dev/null; then
    echo "安装bridge-utils..."
    if command -v yum &> /dev/null; then
        yum install -y bridge-utils
    elif command -v dnf &> /dev/null; then
        dnf install -y bridge-utils
    else
        echo "警告: 无法自动安装bridge-utils，请手动安装"
    fi
fi

# 加载桥接内核模块
echo "加载桥接内核模块..."
modprobe bridge 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true

# 删除现有连接（如果存在）
echo "清理现有连接..."
nmcli connection delete "$BRIDGE_NAME" 2>/dev/null || true
nmcli connection delete "$PHYSICAL_IF" 2>/dev/null || true

# 等待一下确保删除完成
sleep 2

# 创建桥接接口
echo "创建桥接接口 $BRIDGE_NAME..."
nmcli connection add type bridge \
    con-name "$BRIDGE_NAME" \
    ifname "$BRIDGE_NAME" \
    ipv4.addresses "$IP_ADDR" \
    ipv4.gateway "$GATEWAY" \
    ipv4.method manual \
    ipv4.dns "$DNS" \
    bridge.stp yes \
    connection.autoconnect yes

# 将物理网口添加到桥接
echo "将物理网口 $PHYSICAL_IF 添加到桥接..."
nmcli connection add type ethernet \
    con-name "$PHYSICAL_IF" \
    ifname "$PHYSICAL_IF" \
    master "$BRIDGE_NAME" \
    connection.autoconnect yes

# 启用连接
echo "启用网络连接..."
nmcli connection up "$BRIDGE_NAME"
nmcli connection up "$PHYSICAL_IF"

# 等待接口启动
sleep 3

# 验证配置
echo ""
echo "=========================================="
echo "配置完成，验证结果："
echo "=========================================="

echo ""
echo "1. 桥接接口状态："
ip addr show "$BRIDGE_NAME" 2>/dev/null || echo "  警告: $BRIDGE_NAME接口未找到"

echo ""
echo "2. 桥接成员："
brctl show 2>/dev/null || echo "  警告: 无法显示桥接信息"

echo ""
echo "3. 网络连接状态："
nmcli connection show

echo ""
echo "4. 路由表："
ip route show

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "如果$BRIDGE_NAME接口已创建并配置了IP地址，配置成功。"
echo "如果仍有问题，请检查："
echo "  1. NetworkManager服务状态: systemctl status NetworkManager"
echo "  2. NetworkManager日志: journalctl -u NetworkManager -n 50"
echo "  3. 内核模块: lsmod | grep bridge"
echo ""

