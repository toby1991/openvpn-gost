#!/bin/bash
set -e

# 检查OpenVPN配置文件
if [ -z "$OVPN_CONFIG" ] && [ ! -f "/etc/openvpn/config.ovpn" ]; then
    echo "错误: 未找到OpenVPN配置文件。请挂载配置文件到/etc/openvpn/config.ovpn或设置OVPN_CONFIG环境变量指定配置文件路径。"
    exit 1
fi

# 如果设置了OVPN_CONFIG环境变量，使用该变量指定的配置文件
CONFIG_FILE=${OVPN_CONFIG:-"/etc/openvpn/config.ovpn"}

# 启动OpenVPN客户端
echo "正在启动OpenVPN客户端..."
openvpn --config "$CONFIG_FILE" --daemon

# 等待tun0接口创建成功
echo "等待VPN连接建立..."
count=0
while [ $count -lt 30 ]; do
    if ip link show tun0 >/dev/null 2>&1; then
        echo "VPN连接已建立"
        break
    fi
    sleep 1
    count=$((count+1))
done

if [ $count -eq 30 ]; then
    echo "错误: VPN连接建立超时"
    exit 1
fi

# 设置Gost代理参数
SOCKS_PORT=${SOCKS_PORT:-1080}
HTTP_PORT=${HTTP_PORT:-8080}

# 启动Gost代理服务
echo "正在启动Gost代理服务..."
echo "SOCKS5代理端口: $SOCKS_PORT"
echo "HTTP代理端口: $HTTP_PORT"

# 启动Gost代理服务器
gost -L "socks5://:$SOCKS_PORT" -L "http://:$HTTP_PORT" &

# 输出代理信息
echo "代理服务已启动:"
echo "- SOCKS5代理: 0.0.0.0:$SOCKS_PORT"
echo "- HTTP代理: 0.0.0.0:$HTTP_PORT"

# 保持容器运行
echo "服务已启动，容器保持运行中..."
tail -f /dev/null