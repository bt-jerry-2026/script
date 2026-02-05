#!/bin/bash

# --- 配置区 ---
NODE_PATH="/root/.nvm/versions/node/v24.13.0/bin/"
SLACK_TARGET="channel:C0ABBUWJQJY"

# --- 发送 Slack 通知函数 ---
send_slack_notification() {
    local message=$1

    $NODE_PATH/openclaw message send --target "$SLACK_TARGET" --message "🦞:"$'\n'"$message"
}


# 检查是否提供了参数
if [ $# -eq 0 ]; then
    echo "错误: 请提供要发送的消息内容"
    echo "用法: $0 <消息内容>"
    exit 1
fi

# 将所有参数用换行符拼接为一条消息
message=""
for arg in "$@"; do
    if [ -z "$message" ]; then
        message="$arg"
    else
        message="$message"$'\n'"$arg"
    fi
done

send_slack_notification "$message"