#!/bin/bash

# --- 配置区 ---
HOSTNAME=$(hostname)
NODE_PATH="/root/.nvm/versions/node/v24.13.0/bin/"
SERVICES=("nginx" "mongod")
PM2_APP_NAME="orz2-backend"
SLACK_TARGET="U08P298K3EX"
# SLACK_WEBHOOK_URL=""

# --- 发送 Slack 通知函数 ---
send_slack_notification() {
    local message=$1
    # curl -X POST -H 'Content-type: application/json' \
    # --data "{\"text\": \"[$HOSTNAME] 服务监控报告:\n$message\"}" \
    # $SLACK_WEBHOOK_URL

    # 构建完整的消息（REPORT 中已包含实际换行符）
    $NODE_PATH/openclaw message send --target "$SLACK_TARGET" --message "[$HOSTNAME] 服务监控报告:"$'\n'"$message"
}

# --- 核心逻辑 ---
REPORT=""

for SERVICE in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$SERVICE"; then
        # 如果服务正常，可以选择不汇报，或者记录在报告中
        REPORT+=":white_check_mark: $SERVICE 运行正常。"$'\n'
    else
        REPORT+=":warning: $SERVICE 异常停止，尝试重启中..."$'\n'
        
        # 尝试重启
        systemctl restart "$SERVICE"
        
        # 再次检查状态
        sleep 2 # 等待服务启动
        if systemctl is-active --quiet "$SERVICE"; then
            REPORT+=":white_check_mark: $SERVICE 已成功自动重启！"$'\n'
        else
            REPORT+=":fire: $SERVICE 重启失败，请人工介入检查！"$'\n'
        fi
    fi
done

# --- 检查 PM2 托管服务 ---
# 检查 pm2 命令是否可用
if command -v pm2 &> /dev/null || [ -f "$NODE_PATH/pm2" ]; then
    PM2_CMD="pm2"
    if [ -f "$NODE_PATH/pm2" ]; then
        PM2_CMD="$NODE_PATH/pm2"
    fi
    
    # 检查 PM2 应用状态（使用 pm2 list 检查是否包含 online 状态）
    PM2_LIST_OUTPUT=$($PM2_CMD list 2>/dev/null | grep -w "$PM2_APP_NAME" 2>/dev/null)
    
    if echo "$PM2_LIST_OUTPUT" | grep -q "online"; then
        REPORT+=":white_check_mark: PM2应用 $PM2_APP_NAME 运行正常。"$'\n'
    else
        # 检查应用是否存在于 pm2 列表中（可能已停止）
        if [ -n "$PM2_LIST_OUTPUT" ]; then
            REPORT+=":warning: PM2应用 $PM2_APP_NAME 异常停止，尝试重启中..."$'\n'
            $PM2_CMD restart "$PM2_APP_NAME" 2>/dev/null
        else
            REPORT+=":warning: PM2应用 $PM2_APP_NAME 未找到，尝试启动中..."$'\n'
            $PM2_CMD start "$PM2_APP_NAME" 2>/dev/null
        fi
        
        # 等待服务启动
        sleep 3
        
        # 再次检查状态
        PM2_LIST_OUTPUT_AFTER=$($PM2_CMD list 2>/dev/null | grep -w "$PM2_APP_NAME" 2>/dev/null)
        if echo "$PM2_LIST_OUTPUT_AFTER" | grep -q "online"; then
            REPORT+=":white_check_mark: PM2应用 $PM2_APP_NAME 已成功自动重启！"$'\n'
        else
            REPORT+=":fire: PM2应用 $PM2_APP_NAME 重启失败，请人工介入检查！"$'\n'
        fi
    fi
else
    REPORT+=":warning: 未找到 pm2 命令，跳过 PM2 服务检查。"$'\n'
fi

# 发送报告（如果您希望只有异常时才发，可以给这个调用加个判断）
send_slack_notification "$REPORT"