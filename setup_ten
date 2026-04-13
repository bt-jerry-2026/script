#!/bin/bash

# =================================================================
# 功能: 幂等性 Node.js, Nginx, Certbot SSL 自动化配置 (2026 增强版)
# =================================================================

set -e

# --- 变量配置 ---
EMAIL="bt.jerry.2026@gmail.com"
DOMAIN="xshuliner.online"
NODE_VERSION="24"
CONF_PATH="/etc/nginx/conf.d/${DOMAIN}.conf"

# 颜色输出
info() { echo -e "\033[32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
error() { echo -e "\033[31m[ERROR]\033[0m $1"; exit 1; }

echo ">>>> 开始系统初始化配置 <<<<"

# --- 0. 确认包管理器 ---
if command -v dnf >/dev/null; then
    PKG_MANAGER="dnf"
elif command -v apt-get >/dev/null; then
    PKG_MANAGER="apt-get"
else
    error "未检测到支持的包管理器 (dnf/apt)。"
fi

# --- 1. 安装 nvm 与 Node.js ---
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    info "正在安装 nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# 加载 NVM 环境
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! command -v node >/dev/null || [ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" != "$NODE_VERSION" ]; then
    info "正在安装/切换至 Node.js ${NODE_VERSION}..."
    nvm install $NODE_VERSION
    nvm alias default $NODE_VERSION
    nvm use default
else
    info "Node.js ${NODE_VERSION} 已经就绪。"
fi

# --- 2. 生成 SSH 密钥 ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    info "正在生成 SSH ed25519 密钥..."
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519 -N ""
else
    info "SSH 密钥已存在。"
fi

# --- 3. Nginx 安装 ---
if ! command -v nginx >/dev/null; then
    info "正在安装 Nginx..."
    sudo $PKG_MANAGER update -y
    sudo $PKG_MANAGER install nginx -y
    sudo systemctl enable --now nginx
fi

# --- 4. 预配置 80 端口 (用于 SSL 验证) ---
# 如果证书不存在，先建一个极简 80 配置，确保 Certbot 验证顺利
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    info "配置临时 HTTP 环境以进行证书申请..."
    sudo tee $CONF_PATH > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    location /.well-known/acme-challenge/ { root /usr/share/nginx/html; }
}
EOF
    sudo nginx -t && sudo systemctl reload nginx
fi

# --- 5. 安装 Certbot ---
if ! command -v certbot >/dev/null; then
    info "正在安装 Certbot..."
    if [ "$PKG_MANAGER" == "dnf" ]; then
        sudo dnf install certbot python3-certbot-nginx -y
    else
        sudo apt-get install certbot python3-certbot-nginx -y
    fi
fi

# --- 6. 申请 SSL 证书 ---
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    info "开始向 Let's Encrypt 申请证书..."
    sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --email $EMAIL --agree-tos --no-eff-email --non-interactive
else
    info "SSL 证书已存在，准备更新 Nginx 最终配置。"
fi

# --- 7. 写入最终生产级 Nginx 配置 ---
# 注意：在 HEREDOC 中使用 \$ 来保留 Nginx 变量，防止被 Shell 提前解析
info "写入最终 Nginx HTTPS 配置..."
sudo tee $CONF_PATH > /dev/null <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    return 301 https://${DOMAIN}\$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # 安全增强配置
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    location /openclaw/ {
        proxy_pass http://127.0.0.1:18789/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_read_timeout 3600s;
        proxy_buffering off;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files \$uri \$uri/ =404;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name www.${DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    return 301 https://${DOMAIN}\$request_uri;
}
EOF

# --- 8. 自动化续签任务 ---
info "配置 Certbot 自动续签..."
echo "15 3 * * * root /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'" | sudo tee /etc/cron.d/certbot > /dev/null
sudo chmod 644 /etc/cron.d/certbot

# 最终检查
sudo nginx -t && sudo systemctl reload nginx

# --- 9. 结果展示 ---
info "配置完成！"
echo "------------------------------------------------"
echo "Node 版本: $(node -v)"
echo "Nginx 状态: 已启用 HTTPS 并配置了 /openclaw 代理"
echo "SSH 公钥 (请手动复制到 GitHub):"
cat ~/.ssh/id_ed25519.pub
echo "------------------------------------------------"
warn "请确保您的防火墙已开放 80/tcp 和 443/tcp 端口。"
