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








# --- PS ---
# dd if=/dev/zero of=/swapfile bs=1M count=2048
# mkswap /swapfile && swapon /swapfile
# echo '/swapfile none swap sw 0 0' >> /etc/fstab
