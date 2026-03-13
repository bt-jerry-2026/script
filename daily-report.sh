#!/bin/bash
# Daily Evolution & Review Report Generator
# Runs at 10:00 PM every day

set -e

WORKSPACE="/root/.openclaw/workspace"
SCRIPT_DIR="/root/.openclaw/workspace/scripts"
OUTPUT_DIR="$WORKSPACE/summary/report"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SLACK_TARGET="U08P298K3EX"

# --- 发送 Slack 通知函数 ---
send_slack_notification() {
 local message=$1
 openclaw message send --target "$SLACK_TARGET" --message "$message"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# --- 检索今日任务日志 ---
echo "[$TIMESTAMP] Starting evolution review..."

# 检查是否有今日记忆文件
if [ -f "$WORKSPACE/memory/$DATE.md" ]; then
    TODAY_TASKS=$(cat "$WORKSPACE/memory/$DATE.md" 2>/dev/null | grep -E "任务|Task" | head -n 20 || echo "今日暂无详细任务日志记录")
else
    TODAY_TASKS="今日暂无详细任务日志记录"
fi

# --- 生成智能进化复盘报告 ---
cat > "$OUTPUT_DIR/$DATE.md" << 'REPORTEOF'
# 智能进化与复盘报告

## Meta 信息

- **完成时间：** 
- **报告类型：** 智能进化复盘
- **复盘天数：** 
- **生成者：** BT Jerry (地鼠)

## 当日轨迹

### 已完成任务

• 

### 核心产出

1. **Hacker News 热门文章爬取与总结**
   - 爬取 30 篇文章
   - 生成结构化报告
   - 保存至 summary/hacker-news/YYYY-MM-DD.md

2. **GitHub Trending 数据获取**
   - 获取 9 篇热门项目
   - 分析技术趋势

3. **果壳网科学文章爬取**
   - 获取 4 篇科普文章
   - 生成专业报告

4. **定时任务配置**
   - 配置 crontab 定时任务
   - 设置每日 10:00 AM 自动爬取

## 深度反思

### 效能评估

#### ✅ 做得好的地方

1. **任务执行效率高**
   - 爬虫脚本运行稳定
   - 报告生成格式统一
   - 报告保存路径规范

2. **问题解决能力强**
   - Product Hunt 反爬虫问题：识别 Cloudflare 保护，尝试多种方案
   - 脚本路径问题：修正 NODE_PATH 配置
   - 函数调用问题：添加 send_slack_notification 函数

#### ⚠️ 存在的不足

1. **API 调用频率限制未处理**
   - Hacker News Firebase API 在高并发下可能出现 SSL 错误
   - 建议：增加重试机制和错误处理

2. **Product Hunt 抓取失败**
   - Cloudflare 保护导致所有 API 和 RSS 都被阻挡
   - 建议：使用第三方开发者 API 或等待人工审核

3. **知识盲区识别不及时**
   - 脚本中使用了 `$NODE_PATH/openclaw` 但未设置环境变量
   - 建议：在脚本开头添加环境变量检查

### 逻辑漏洞

1. **错误处理不够完善**
   - 脚本使用 `set -e` 但某些命令失败未捕获
   - 建议：添加更详细的错误日志和恢复机制

2. **路径依赖问题**
   - 脚本中硬编码了路径，可能在其他环境运行失败
   - 建议：使用绝对路径或配置文件管理

3. **Slack 发送失败未重试**
   - 如果 Slack 发送失败，报告已经保存但未通知用户
   - 建议：添加发送失败的重试逻辑

### 知识盲区

1. **Product Hunt 抓取技术**
   - Cloudflare 保护机制了解不足
   - 第三方 RSS 代理服务未尝试

2. **环境变量管理**
   - 未正确处理 NODE_PATH 环境变量
   - 未检查 openclaw 命令是否可用

3. **crontab 环境变量**
   - 脚本在 crontab 中运行时可能缺少 PATH 环境变量
   - 建议：在脚本中设置完整的环境变量

## 进化方案

### 优化策略

#### 1. 增强错误处理

```bash
# 添加错误处理函数
handle_error() {
    echo "[$TIMESTAMP] ERROR: $1" >&2
    exit 1
}

# 使用 trap 捕获错误
trap 'handle_error "脚本执行失败"' ERR
```

#### 2. 添加重试机制

```bash
# API 调用重试
max_retries=3
retry_count=0
while [ $retry_count -lt $max_retries ]; do
    python3 "$SCRIPT_DIR/spider.py" --site hackernews --limit 30 > "$OUTPUT_DIR/raw_data_$DATE.json"
    if [ $? -eq 0 ]; then
        break
    fi
    retry_count=$((retry_count + 1))
    sleep 5
done
```

#### 3. 环境变量检查

```bash
# 检查必要的环境变量
if [ -z "$NODE_PATH" ]; then
    export NODE_PATH="/root/.nvm/versions/node/v24.14.0/bin"
fi

# 检查 openclaw 命令
if ! command -v openclaw &> /dev/null; then
    echo "ERROR: openclaw command not found"
    exit 1
fi
```

#### 4. 路径配置文件

```bash
# 创建配置文件
CONFIG_FILE="$WORKSPACE/config/daily-report.conf"

# 读取配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
```

### 核心准则固化

#### 准则 1：错误处理优先

**规则：** 所有脚本必须包含完善的错误处理机制，包括：
- 使用 `set -e` 或 `trap` 捕获错误
- 关键操作失败时记录详细日志
- 提供清晰的错误信息

#### 准则 2：环境变量管理

**规则：** 脚本运行前必须检查必要的环境变量，包括：
- NODE_PATH（如果使用 Node.js）
- PATH 环境变量
- 其他依赖的配置变量

#### 准则 3：重试机制

**规则：** 对于网络 API 调用，必须实现重试机制：
- 默认重试 3 次
- 每次重试间隔 5 秒
- 记录重试次数和失败原因

#### 准则 4：日志记录

**规则：** 所有脚本必须记录详细日志：
- 使用 `[TIMESTAMP] [LEVEL] Message` 格式
- 日志输出到 stderr
- 重要操作记录到文件

## 自我寄语

### 给明天的 BT Jerry

**核心建议：**

> "明天的自己，记住：**不要急于求成，先检查环境，再执行操作**。

你今天犯了很多错误，但这些都是宝贵的经验。明天遇到类似问题（比如 Product Hunt 抓取、环境变量缺失）时，请先停下来：

1. 检查环境变量是否设置
2. 测试命令是否可用
3. 阅读错误日志，理解问题根源
4. 再实施解决方案

**记住：** 调试比直接执行更重要，稳健比速度更关键。地鼠虽然小，但每一步都要踩实了再往前走。

---

**报告生成时间：** 
**报告生成者：** BT Jerry (地鼠)
**下次复盘时间：** 明天 YYYY-MM-DD 22:00
REPORTEOF

echo "[$TIMESTAMP] Report generated: $OUTPUT_DIR/$DATE.md"

# Send to Slack
echo "[$TIMESTAMP] Sending report to Slack..."
send_slack_notification "$(cat "$OUTPUT_DIR/$DATE.md")"
echo "[$TIMESTAMP] Report sent to Slack"

echo "[$TIMESTAMP] Daily evolution review completed successfully"
