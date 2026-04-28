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
process_repo() {
    local repo_path="$1"
    echo "================================================"
    echo "Processing repository: $repo_path"
    echo "================================================"

    # 检查目录是否存在
    if [[ ! -d "$repo_path" ]]; then
        echo "[ERROR] Directory does not exist: $repo_path" >&2
        return 1
    fi

    # 检查是否为 Git 仓库
    if [[ ! -d "$repo_path/.git" ]]; then
        echo "[ERROR] Not a Git repository: $repo_path" >&2
        return 1
    fi

    # 进入仓库目录
    cd "$repo_path" || {
        echo "[ERROR] Cannot cd into $repo_path" >&2
        return 1
    }

    echo "[INFO] Current directory: $(pwd)"

    # git pull
    echo "[INFO] Running git pull ..."
    if git pull; then
        echo "[OK] git pull succeeded"
    else
        echo "[ERROR] git pull failed" >&2
        return 1
    fi

    # 检查是否有变更需要提交（工作区或暂存区）
    if [[ -z "$(git status --porcelain)" ]]; then
        echo "[INFO] No changes to commit, skipping add/commit/push."
        return 0
    fi

    # git add .
    echo "[INFO] Running git add ."
    if git add .; then
        echo "[OK] git add . succeeded"
    else
        echo "[ERROR] git add . failed" >&2
        return 1
    fi

    # git commit -m 使用常量 COMMIT_MSG
    echo "[INFO] Running git commit -m \"$COMMIT_MSG\""
    if git commit -m "$COMMIT_MSG"; then
        echo "[OK] git commit succeeded"
    else
        echo "[ERROR] git commit failed" >&2
        return 1
    fi

    # git push
    echo "[INFO] Running git push"
    if git push; then
        echo "[OK] git push succeeded"
    else
        echo "[ERROR] git push failed" >&2
        return 1
    fi

    echo "[INFO] Successfully processed $repo_path"
    return 0
}

# 主循环
main() {
    local failed=()
    for repo in "${directories[@]}"; do
        process_repo "$repo"
        if [[ $? -ne 0 ]]; then
            failed+=("$repo")
        fi
        echo ""   # 输出空行分隔不同仓库的日志
    done

    # 最终汇总
    echo "================================================"
    echo "Summary:"
    if [[ ${#failed[@]} -eq 0 ]]; then
        echo "All repositories processed successfully."
    else
        echo "The following repositories encountered errors:"
        for f in "${failed[@]}"; do
            echo "  - $f"
        done
    fi
    echo "================================================"
}

# 执行主函数
main
