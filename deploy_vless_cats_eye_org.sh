#!/bin/bash

# === CONFIGURATION ===
UUID="fa521473-4d26-4ad2-9b92-51875cd4a165"
DOMAIN="cats-eye.org"
GRPC_PATH="/images/sync"
V2RAY_PORT=10000

echo "🔧 开始配置 V2Ray + Nginx + Hugo + TLS (443)..."

# 1. 配置 V2Ray
cat <<EOF > /usr/local/etc/v2ray/config.json
{
  "inbounds": [
    {
      "port": $V2RAY_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{ "id": "$UUID", "level": 0 }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "${GRPC_PATH##/}" },
        "security": "none"
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

echo "✅ V2Ray 配置完成"

# 2. 安装并配置 Hugo 伪装网站
apt update
apt install hugo -y
hugo new site /var/www/html/myblog
cd /var/www/html/myblog
git clone https://github.com/theNewDynamic/gohugo-theme-ananke themes/ananke
echo 'theme = "ananke"' >> config.toml
hugo new posts/welcome.md
echo -e "---\ntitle: '欢迎'\ndate: $(date +%Y-%m-%d)\n---\n欢迎来到我的博客！" > content/posts/welcome.md
hugo
cp -r public/* /var/www/html/

echo "✅ Hugo 伪装网站部署完成"

# 3. 配置 Nginx
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location $GRPC_PATH {
        grpc_pass grpc://127.0.0.1:$V2RAY_PORT;
        error_page 502 = /error.html;
    }

    location / {
        root /var/www/html;
        index index.html;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://$host$request_uri;
}
EOF

echo "✅ Nginx 配置完成"

# 4. 获取 TLS 证书
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# 5. 放行端口
ufw allow 443
ufw allow $V2RAY_PORT

# 6. 重启服务
systemctl restart v2ray
systemctl restart nginx

# 7. 输出连接信息
echo "✅ 所有配置已完成，以下是你的连接信息："
echo "======================================="
echo "协议：VLESS"
echo "地址：$DOMAIN"
echo "端口：443"
echo "UUID：$UUID"
echo "加密：none"
echo "传输层：gRPC"
echo "路径：$GRPC_PATH"
echo "TLS：开启"
echo "SNI：$DOMAIN"
echo "指纹伪装：建议 chrome / safari（客户端选择）"
echo "======================================="
