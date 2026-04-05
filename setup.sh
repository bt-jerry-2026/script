#!/bin/bash

# =================================================================
# 脚本名称: setup_server.sh
# 适用环境: CentOS / RHEL / Fedora (使用 yum/dnf)
# 功能: 安装 Node.js, Git, Nginx, Certbot SSL, 以及配置 Swap
# =================================================================

# 报错即停止运行
set -e

# --- 变量配置 ---
EMAIL="bt.jerry.2026@gmail.com"
DOMAIN="xshuliner.online"
# SWAP_SIZE_MB=2048
NODE_VERSION="24"
CONF_PATH="/etc/nginx/conf.d/${DOMAIN}.conf"

echo ">>>> 开始系统初始化配置 <<<<"

# --- 1. 系统更新与基础依赖 ---
echo "正在更新系统软件包..."
sudo dnf update -y
sudo dnf install -y git curl python3 python3-pip python3-devel augeas-libs

# --- 2. 配置 Swap 分区 (预防 OOM 内存溢出) ---
# 检查是否已经存在 swapfile
# if [ ! -f /swapfile ]; then
#     echo "正在创建 ${SWAP_SIZE_MB}MB Swap 分区..."
#     sudo dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE_MB
#     sudo chmod 600 /swapfile
#     sudo mkswap /swapfile
#     sudo swapon /swapfile
#     echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
#     echo "Swap 分区配置完成。"
# else
#     echo "Swap 分区已存在，跳过。"
# fi

# --- 3. 安装 nvm 与 Node.js ---
if [ ! -d "$HOME/.nvm" ]; then
    echo "正在安装 nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# 加载 nvm 环境到当前 shell 会话
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "正在通过 nvm 安装 Node.js ${NODE_VERSION}..."
nvm install $NODE_VERSION
nvm use $NODE_VERSION
nvm alias default $NODE_VERSION

# --- 4. 生成 SSH 密钥 ---
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "正在生成 SSH ed25519 密钥..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519 -N ""
else
    echo "SSH 密钥已存在，跳过生成。"
fi

# --- 5. 安装与配置 Nginx ---
echo "正在安装 Nginx..."
sudo dnf install nginx -y
sudo systemctl enable --now nginx

echo "开始写入 Nginx 配置文件: $CONF_PATH"
# 使用 sudo tee 写入需要权限的文件，避免 EOF 权限问题
sudo tee $CONF_PATH > /dev/null <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    return 301 https://${DOMAIN}\$request_uri;
}

# HTTPS 核心配置
server {
    listen 443 ssl;
    http2 on;
    server_name ${DOMAIN};

    # 证书路径由 Certbot 生成后自动填入
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

# www 重定向到 non-www
server {
    listen 443 ssl;
    http2 on;
    server_name www.${DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    return 301 https://${DOMAIN}\$request_uri;
}
EOF

# --- 6. 安装 Certbot 并自动化续签 ---
echo "配置 Certbot SSL..."
if [ ! -d "/opt/certbot" ]; then
    sudo python3 -m venv /opt/certbot/
    sudo /opt/certbot/bin/pip install --upgrade pip
    sudo /opt/certbot/bin/pip install certbot certbot-nginx
    sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
fi

# 仅在证书不存在时申请
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --email $EMAIL --agree-tos --no-eff-email --non-interactive
else
    echo "SSL 证书已存在，跳过申请。"
fi

# 设置每天凌晨 3:15 检查续签 Cron 任务，如果续签成功则重载 nginx
CRON_JOB="15 3 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'"
(sudo crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_JOB") | sudo crontab -

# --- 7. 最后检查与清理 ---
sudo nginx -t && sudo systemctl reload nginx

echo "------------------------------------------------"
echo "🎉 所有的安装与配置已完成！"
echo "Node 版本: $(node -v)"
echo "Nginx 状态: 已启动并配置自动续签"
echo "Swap 状态: 已开启 ${SWAP_SIZE_MB}MB"
echo "------------------------------------------------"
echo "以下是您的 SSH 公钥，请添加到 GitHub/GitLab:"
cat ~/.ssh/id_ed25519.pub
echo "------------------------------------------------"
echo "提示: 请执行 'source ~/.bashrc' 来使 nvm 在当前终端生效。"
