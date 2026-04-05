#!/bin/bash

# =================================================================
# 功能: 支持幂等性的 Node.js, Nginx, Certbot SSL 自动化配置
# 修复: 解决了 Crontab 写入失败、NVM 路径加载以及 Nginx 证书死循环问题
# =================================================================

set -e

# --- 变量配置 ---
EMAIL="bt.jerry.2026@gmail.com"
DOMAIN="xshuliner.online"
NODE_VERSION="24"
CONF_PATH="/etc/nginx/conf.d/${DOMAIN}.conf"
SWAP_SIZE_MB=2048

echo ">>>> 开始系统初始化配置 <<<<"

# --- 1. 系统更新与基础依赖 ---
echo "正在检查并安装基础依赖..."
sudo dnf install -y git curl python3 python3-pip python3-devel augeas-libs > /dev/null

# --- 2. 配置 Swap (如果不存在则创建) ---
if [ ! -f /swapfile ]; then
    echo "正在创建 ${SWAP_SIZE_MB}MB Swap 分区..."
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE_MB
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
    echo "Swap 分区已存在，跳过。"
fi

# --- 3. 安装 nvm 与 Node.js (幂等处理) ---
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    echo "正在安装 nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# 核心修复：强制加载当前 Shell 的 nvm 环境
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! nvm ls $NODE_VERSION >/dev/null 2>&1; then
    echo "正在安装 Node.js ${NODE_VERSION}..."
    nvm install $NODE_VERSION
    nvm alias default $NODE_VERSION
    nvm use default
else
    echo "Node.js ${NODE_VERSION} 已安装，跳过。"
fi

# --- 4. 生成 SSH 密钥 (如果不存在则生成) ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "正在生成 SSH ed25519 密钥..."
    mkdir -p ~/.ssh
    ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519 -N ""
else
    echo "SSH 密钥已存在，跳过生成。"
fi

# --- 5. Nginx 安装与初始配置 ---
if [ ! -x "/usr/sbin/nginx" ]; then
    echo "正在安装 Nginx..."
    sudo dnf install nginx -y
    sudo systemctl enable --now nginx
fi

# 【逻辑修复】: 如果证书不存在，先配置一个基础 80 端口用于 Certbot 验证
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "检测到证书未就绪，配置临时 HTTP 服务以供验证..."
    sudo tee $CONF_PATH > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    location /.well-known/acme-challenge/ { root /usr/share/nginx/html; }
    location / { return 301 https://\$host\$request_uri; }
}
EOF
    sudo nginx -t && sudo systemctl reload nginx
fi

# --- 6. 安装 Certbot (使用 venv 模式) ---
if [ ! -x "/usr/bin/certbot" ]; then
    echo "正在配置 Certbot..."
    sudo python3 -m venv /opt/certbot/
    sudo /opt/certbot/bin/pip install --upgrade pip
    sudo /opt/certbot/bin/pip install certbot certbot-nginx
    sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
fi

# 仅在证书文件夹不存在时申请
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo "正在向 Let's Encrypt 申请 SSL 证书..."
    sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --email $EMAIL --agree-tos --no-eff-email --non-interactive
fi

# --- 7. 写入正式的 HTTPS 配置文件 ---
echo "写入最终 Nginx 配置..."
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

    location /openclaw/ {
        proxy_pass http://127.0.0.1:18789;
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

# --- 8. 自动化续签任务 (采用 system-wide cron 方式，更稳定) ---
echo "配置 Certbot 自动续签任务..."
echo "15 3 * * * root /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'" | sudo tee /etc/cron.d/certbot > /dev/null
sudo chmod 644 /etc/cron.d/certbot

# 最后检查并重载 Nginx
sudo nginx -t && sudo systemctl reload nginx

# --- 9. 结果展示 ---
echo ""
echo "------------------------------------------------"
echo "🎉 所有的安装与配置已完成！"
echo "Node 版本: $(node -v 2>/dev/null || echo '需重启终端或执行 source ~/.bashrc')"
echo "Nginx 状态: 配置已生效，支持 HTTPS"
echo "Swap 状态: $(free -m | grep Swap | awk '{print $2}')MB"
echo "------------------------------------------------"
echo "🎉 定时任务已存至: /etc/cron.d/certbot"
echo "内容: $(cat /etc/cron.d/certbot)"
echo "------------------------------------------------"
echo "👇 您的 SSH 公钥 (ed25519) 如下，请添加到 GitHub:"
echo ""
cat ~/.ssh/id_ed25519.pub
echo ""
echo "------------------------------------------------"
echo "💡 提示: 如果 node 命令不生效，请手动执行:"
echo "source ~/.bashrc"
echo "------------------------------------------------"
