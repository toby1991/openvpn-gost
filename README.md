# OpenVPN + Gost 代理 Docker 镜像

这个Docker镜像结合了OpenVPN客户端和Gost代理工具，允许你通过SOCKS5或HTTP代理将流量转发到OpenVPN隧道。

## 功能特点

- 基于Alpine Linux的轻量级镜像
- 支持挂载自定义OpenVPN配置文件
- 提供SOCKS5和HTTP代理服务
- 可自定义代理端口

## 构建镜像

```bash
docker build -t openvpn-gost .
```

## 运行容器

### 基本用法

```bash
docker run -d \
  --name openvpn-gost \
  --cap-add=NET_ADMIN \
  -v /path/to/your/config.ovpn:/etc/openvpn/config.ovpn \
  -p 1080:1080 \
  -p 8080:8080 \
  openvpn-gost
```

### 环境变量

你可以通过环境变量自定义容器的行为：

- `OVPN_CONFIG`: OpenVPN配置文件的路径（默认为`/etc/openvpn/config.ovpn`）
- `SOCKS_PORT`: SOCKS5代理端口（默认为`1080`）
- `HTTP_PORT`: HTTP代理端口（默认为`8080`）

### 故障排除

1. TUN设备相关问题
   - 错误信息：`错误: TUN设备不存在。请确保容器已正确挂载TUN设备。`
   - 解决方案：
     1. 确保主机系统支持TUN设备
     2. 检查TUN设备是否存在：`ls /dev/net/tun`
     3. 确保在运行容器时使用了`--device=/dev/net/tun:/dev/net/tun`参数
     4. 在Kubernetes环境中，确保Pod配置了正确的权限和设备挂载

2. OpenVPN连接问题
   - 如果VPN连接失败，可以查看容器日志获取详细错误信息：
     ```bash
     docker logs openvpn-gost
     ```

例如：

```bash
docker run -d \
  --name openvpn-gost \
  --cap-add=NET_ADMIN \
  -v /path/to/your/config.ovpn:/etc/openvpn/config.ovpn \
  -e SOCKS_PORT=1081 \
  -e HTTP_PORT=8081 \
  -p 1081:1081 \
  -p 8081:8081 \
  openvpn-gost
```

## 使用方法

1. 准备你的OpenVPN配置文件（`.ovpn`）
2. 启动容器，挂载配置文件
3. 容器会自动连接到VPN并启动代理服务
4. 配置你的应用程序使用以下代理：
   - SOCKS5代理：`<容器IP>:1080`（或你自定义的端口）
   - HTTP代理：`<容器IP>:8080`（或你自定义的端口）

## 注意事项

- 容器需要`NET_ADMIN`权限才能创建VPN隧道
- 确保你的OpenVPN配置文件正确且有效
- 如果连接失败，可以查看容器日志获取详细信息：`docker logs openvpn-gost`

## 在Kubernetes中使用

在Kubernetes环境中，你可以使用以下示例部署：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openvpn-gost
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openvpn-gost
  template:
    metadata:
      labels:
        app: openvpn-gost
    spec:
      containers:
      - name: openvpn-gost
        image: openvpn-gost:latest
        securityContext:
          capabilities:
            add: ["NET_ADMIN"]
        ports:
        - containerPort: 1080
          name: socks
        - containerPort: 8080
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/openvpn/config.ovpn
          subPath: config.ovpn
      volumes:
      - name: config
        configMap:
          name: openvpn-config
---
apiVersion: v1
kind: Service
metadata:
  name: openvpn-gost
spec:
  selector:
    app: openvpn-gost
  ports:
  - name: socks
    port: 1080
    targetPort: 1080
  - name: http
    port: 8080
    targetPort: 8080
```

创建包含OpenVPN配置的ConfigMap：

```bash
kubectl create configmap openvpn-config --from-file=config.ovpn=/path/to/your/config.ovpn
```