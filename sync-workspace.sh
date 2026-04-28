#!/bin/bash

# 常量定义
COMMIT_MSG="update from tencent"

# 定义仓库目录列表
directories=(
    "/root/.openclaw/workspace-agent-aliyun-shuxiaolan"
    "/root/.openclaw/workspace-agent-aliyun-shuxiaolv"
    "/root/.openclaw/workspace-agent-aliyun-shuxiaozi"
    "/root/.openclaw/workspace-agent-aliyun-shuxiaohong"
    "/root/.openclaw/workspace-agent-aliyun-shuxiaohuang"
    "/root/.openclaw/workspace-agent-aliyun-shuxiaocheng"
)

# 处理单个仓库的函数
# 参数: $1 = 仓库路径, $2 = 模式 (pull 或 push)
process_repo() {
    local repo_path="$1"
    local mode="$2"
    echo "================================================"
    echo "📂 正在处理仓库: $repo_path (模式: $mode)"
    echo "================================================"

    # 检查目录是否存在
    if [[ ! -d "$repo_path" ]]; then
        echo "❌ 错误: 目录不存在 -> $repo_path" >&2
        return 1
    fi

    # 检查是否为 Git 仓库
    if [[ ! -d "$repo_path/.git" ]]; then
        echo "❌ 错误: 不是 Git 仓库 -> $repo_path" >&2
        return 1
    fi

    # 进入仓库目录
    cd "$repo_path" || {
        echo "❌ 错误: 无法进入目录 -> $repo_path" >&2
        return 1
    }

    echo "📁 当前目录: $(pwd)"

    # git pull (两种模式都需要)
    echo "⬇️  正在执行 git pull ..."
    if git pull; then
        echo "✅ git pull 成功"
    else
        echo "❌ git pull 失败" >&2
        return 1
    fi

    # 如果是 pull 模式，到此结束
    if [[ "$mode" == "pull" ]]; then
        echo "ℹ️  模式为 'pull'，跳过 add / commit / push。"
        return 0
    fi

    # 以下为 push 模式（完整流程）
    # 检查是否有变更需要提交
    if [[ -z "$(git status --porcelain)" ]]; then
        echo "ℹ️  没有检测到任何变更，跳过 add / commit / push。"
        return 0
    fi

    # git add .
    echo "➕ 正在执行 git add ."
    if git add .; then
        echo "✅ git add . 成功"
    else
        echo "❌ git add . 失败" >&2
        return 1
    fi

    # git commit
    echo "📝 正在执行 git commit -m \"$COMMIT_MSG\""
    if git commit -m "$COMMIT_MSG"; then
        echo "✅ git commit 成功"
    else
        echo "❌ git commit 失败" >&2
        return 1
    fi

    # git push
    echo "📤 正在执行 git push"
    if git push; then
        echo "✅ git push 成功"
    else
        echo "❌ git push 失败" >&2
        return 1
    fi

    echo "🎉 仓库处理完成: $repo_path"
    return 0
}

# 主函数
main() {
    # 确定运行模式：参数为 "push" 则完整流程，否则默认为 "pull"
    local mode="pull"
    if [[ $# -ge 1 && "$1" == "push" ]]; then
        mode="push"
    elif [[ $# -ge 1 && "$1" != "pull" ]]; then
        echo "⚠️  未知参数 '$1'，请使用 'pull' 或 'push'。将默认使用 'pull' 模式。" >&2
    fi
    echo "🚀 运行模式: $mode"

    local failed=()
    for repo in "${directories[@]}"; do
        process_repo "$repo" "$mode"
        if [[ $? -ne 0 ]]; then
            failed+=("$repo")
        fi
        echo ""   # 输出空行分隔不同仓库
    done

    # 最终汇总
    echo "================================================"
    echo "📊 执行汇总："
    if [[ ${#failed[@]} -eq 0 ]]; then
        echo "✅ 所有仓库均处理成功。"
    else
        echo "❌ 以下仓库处理时出现错误："
        for f in "${failed[@]}"; do
            echo "   - $f"
        done
    fi
    echo "================================================"
}

# 执行主函数，传递所有命令行参数
main "$@"
