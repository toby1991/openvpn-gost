FROM --platform=linux/amd64 alpine:latest

# 安装必要的软件包
RUN apk add --no-cache \
    openvpn \
    curl \
    bash \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# 设置工作目录
WORKDIR /app

# 下载并安装gost
RUN GOST_VERSION="2.12.0" \
    && GOST_FILENAME="gost_${GOST_VERSION}_linux_amd64v3.tar.gz" \
    && curl -L -o /tmp/${GOST_FILENAME} https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/${GOST_FILENAME} \
    && tar -zxvf /tmp/${GOST_FILENAME}
    && mv ./gost /usr/local/bin/gost \
    && chmod +x /usr/local/bin/gost \
    && rm -f /tmp/${GOST_FILENAME}

# 创建配置目录
RUN mkdir -p /etc/openvpn

# 复制启动脚本
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# 暴露gost代理端口
EXPOSE 1080 8080

# 设置容器启动命令
CMD ["/app/start.sh"]