#!/bin/bash
set -e

# 日志函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# 检查VPN连接状态
check_vpn_status() {
    if ! ip link show tun0 >/dev/null 2>&1; then
        log "ERROR" "VPN连接已断开，tun0接口不存在"
        return 1
    fi
    
    # 检查路由表
    if ! ip route | grep -q tun0; then
        log "ERROR" "VPN路由表异常"
        return 1
    fi
    
    return 0
}

# 测试网络连通性
test_connectivity() {
    local test_ip=$1
    log "INFO" "测试网络连通性到 $test_ip..."
    if ping -c 3 -W 5 $test_ip >/dev/null 2>&1; then
        log "INFO" "网络连通性测试成功: $test_ip"
        return 0
    else
        log "ERROR" "网络连通性测试失败: $test_ip"
        return 1
    fi
}

# 重启OpenVPN
restart_openvpn() {
    log "WARN" "正在重启OpenVPN..."
    pkill -15 openvpn || true
    sleep 2
    openvpn --config "$CONFIG_FILE" --daemon --status /tmp/openvpn-status.log 5
    
    # 等待tun0接口创建成功
    log "INFO" "等待VPN连接重新建立..."
    count=0
    while [ $count -lt 30 ]; do
        if ip link show tun0 >/dev/null 2>&1; then
            log "INFO" "VPN连接已重新建立"
            return 0
        fi
        sleep 1
        count=$((count+1))
    done
    
    log "ERROR" "VPN重连失败"
    return 1
}

# 检查OpenVPN配置文件
if [ -z "$OVPN_CONFIG" ] && [ ! -f "/etc/openvpn/config.ovpn" ]; then
    log "ERROR" "未找到OpenVPN配置文件。请挂载配置文件到/etc/openvpn/config.ovpn或设置OVPN_CONFIG环境变量指定配置文件路径。"
    exit 1
fi

# 如果设置了OVPN_CONFIG环境变量，使用该变量指定的配置文件
CONFIG_FILE=${OVPN_CONFIG:-"/etc/openvpn/config.ovpn"}
log "INFO" "使用OpenVPN配置文件: $CONFIG_FILE"

# 检查并初始化TUN设备
if [ ! -c /dev/net/tun ]; then
    log "ERROR" "TUN设备不存在。请确保容器已正确挂载TUN设备。"
    exit 1
fi
log "INFO" "TUN设备检查通过"

# 设置测试IP（可以是VPN内网的IP地址）
# 默认使用8.8.8.8，可以通过环境变量TEST_IP自定义
TEST_IP=${TEST_IP:-"8.8.8.8"}
log "INFO" "设置连通性测试IP: $TEST_IP"

# 启动OpenVPN客户端
log "INFO" "正在启动OpenVPN客户端..."
openvpn --config "$CONFIG_FILE" --daemon --status /tmp/openvpn-status.log 5

# 等待tun0接口创建成功
log "INFO" "等待VPN连接建立..."
count=0
while [ $count -lt 30 ]; do
    if ip link show tun0 >/dev/null 2>&1; then
        log "INFO" "VPN连接已建立"
        break
    fi
    sleep 1
    count=$((count+1))
done

if [ $count -eq 30 ]; then
    log "ERROR" "VPN连接建立超时"
    exit 1
fi

# 设置Gost代理参数
SOCKS_PORT=${SOCKS_PORT:-1080}
HTTP_PORT=${HTTP_PORT:-8080}

# 启动Gost代理服务
log "INFO" "正在启动Gost代理服务..."
log "INFO" "SOCKS5代理端口: $SOCKS_PORT"
log "INFO" "HTTP代理端口: $HTTP_PORT"

# 启动Gost代理服务器
gost -L "socks5://:$SOCKS_PORT" -L "http://:$HTTP_PORT" &
GOST_PID=$!
log "INFO" "Gost代理服务已启动，PID: $GOST_PID"

# 输出代理信息
log "INFO" "代理服务已启动:"
log "INFO" "- SOCKS5代理: 0.0.0.0:$SOCKS_PORT"
log "INFO" "- HTTP代理: 0.0.0.0:$HTTP_PORT"

# 定期检查VPN状态并在必要时重连
log "INFO" "启动VPN状态监控..."

# 保持容器运行并监控VPN状态
while true; do
    sleep 30
    
    # 检查OpenVPN进程
    if ! pgrep openvpn >/dev/null; then
        log "WARN" "OpenVPN进程不存在，尝试重启"
        restart_openvpn
        continue
    fi
    
    # 检查VPN状态
    if ! check_vpn_status; then
        log "WARN" "VPN连接状态异常，尝试重启"
        restart_openvpn
        continue
    fi
    
    # 每5分钟执行一次连通性测试
    if [ $(( $(date +%s) % 300 )) -lt 30 ]; then
        test_connectivity "$TEST_IP"
    fi
    
    # 输出OpenVPN状态信息（如果状态文件存在）
    if [ -f /tmp/openvpn-status.log ]; then
        log "INFO" "OpenVPN状态信息:"
        grep -E "Updated|SUCCESS" /tmp/openvpn-status.log | tail -5
    fi
done