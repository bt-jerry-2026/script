#!/bin/bash

# --- 1. 安装 nvm 与 Node.js 24 ---
echo "正在安装 nvm..."
# 下载并运行 nvm 安装脚本
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# 刷新一下当前会话，确保当前进程可以使用 nvm 命令
source ~/.bashrc

echo "正在通过 nvm 安装 Node.js 24..."
nvm install 24
nvm use 24
nvm alias default 24

# --- 2. 安装 git ---
echo "正在安装 git..."
sudo yum install -y git

# --- 3. 创建 SSH 密钥 ---
echo "正在生成 SSH ed25519 密钥..."
# -f 指定路径，-N "" 表示空密码，-q 表示静默模式
ssh-keygen -t ed25519 -C "bt.jerry.2026@gmail.com" -f ~/.ssh/id_ed25519 -N ""

# --- 4. 打印公钥内容 ---
echo "------------------------------------------------"
echo "设置完成！以下是您的公钥内容 (id_ed25519.pub):"
echo "------------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo "------------------------------------------------"

# --- 5. 手动刷新一下当前会话，确保当前进程可以使用 nvm 命令 ---
echo "source ~/.bashrc"
echo "------------------------------------------------"

# --- 6. 安装 nginx ---
# 更新系统软件包
sudo dnf update -y

# 安装 Nginx
sudo dnf install nginx -y

# 启动并设置开机自启
sudo systemctl start nginx
sudo systemctl enable nginx

# 新建域名的 Nginx 配置
DOMAIN="xshuliner.online"
CONF_PATH="/etc/nginx/conf.d/${DOMAIN}.conf"

echo "开始配置 Nginx 虚拟主机..."

# 创建 Nginx 配置文件
# 使用 cat <<EOF 结构直接写入内容
sudo cat <<EOF > $CONF_PATH

map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  server_name www.xshuliner.online;

  return 301 https://xshuliner.online$request_uri;
}

server {
  listen 80;
  server_name xshuliner.online;

  return 301 https://xshuliner.online$request_uri;
}

server {
  listen 443 ssl;
  http2 on;
  server_name www.xshuliner.online;

  ssl_certificate /etc/letsencrypt/live/xshuliner.online/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/xshuliner.online/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  return 301 https://xshuliner.online$request_uri;
}

server {
  listen 443 ssl;
  http2 on;
  server_name xshuliner.online;

  ssl_certificate /etc/letsencrypt/live/xshuliner.online/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/xshuliner.online/privkey.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  location = /openclaw {
    proxy_pass http://127.0.0.1:18789/openclaw/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_buffering off;
  }

  location /openclaw/ {
    proxy_pass http://127.0.0.1:18789;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_buffering off;
  }

  location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
    try_files $uri $uri/ =404;
  }
}

EOF

echo "配置文件已创建: $CONF_PATH"

# 检查 Nginx 配置语法
sudo nginx -t
if [ $? -eq 0 ]; then
    echo "Nginx 配置语法正确，正在重载..."
    sudo systemctl reload nginx
else
    echo "Nginx 配置错误，请检查！"
    exit 1
fi

# --- 7. 安装 Certbot
# 安装 Python 3 基础环境
sudo dnf install python3 python3-pip python3-devel augeas-libs -y

# 使用虚拟环境安装 Certbot
# 创建虚拟环境目录
sudo python3 -m venv /opt/certbot/
# 升级虚拟环境内的 pip
sudo /opt/certbot/bin/pip install --upgrade pip
# 安装 certbot 和 nginx 插件
sudo /opt/certbot/bin/pip install certbot certbot-nginx
# 创建命令软链接
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot
# 申请 SSL 证书
sudo certbot --nginx -d xshuliner.online --email bt.jerry.2026@gmail.com --agree-tos --no-eff-email

# TODO: 配置自动续签 SSL 证书
# sudo crontab -e
# 0 0,12 * * * /usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"





# --- PS: OOM ---

# export NODE_OPTIONS="--max-old-space-size=4096"

# dd if=/dev/zero of=/swapfile bs=1M count=2048
# mkswap /swapfile && swapon /swapfile
# echo '/swapfile none swap sw 0 0' >> /etc/fstab
