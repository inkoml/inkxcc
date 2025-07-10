#!/bin/bash
cd "$(dirname "$0")"

# 设置代理（如果你需要）
export https_proxy=http://127.0.0.1:1080
export http_proxy=http://127.0.0.1:1080
export all_proxy=socks5://127.0.0.1:1080

# 获取当前分支名
current_branch=$(git symbolic-ref --short HEAD)

echo "🔄 拉取远程分支 origin/$current_branch 的最新内容..."

# 拉取并使用 rebase（推荐，避免产生多余 merge 提交）
git fetch origin
git rebase origin/"$current_branch"

if [ $? -ne 0 ]; then
  echo "❌ rebase 失败，请手动解决冲突后再运行 pull.sh"
  exit 1
fi

echo "✅ 拉取完成，已是最新内容。"
