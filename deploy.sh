#!/bin/bash
cd "$(dirname "$0")"

# vpn
export https_proxy=http://127.0.0.1:1080;
export http_proxy=http://127.0.0.1:1080;
export all_proxy=socks5://127.0.0.1:1080

git rm --cached -r .obsidian


echo "📦 添加改动..."
git add .

# 检查是否有改动需要提交
if git diff --cached --quiet; then
  echo "⚠️ 没有检测到改动，跳过提交。"
else
  echo "📝 提交中：内容更新：$(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "内容更新：$(date '+%Y-%m-%d %H:%M:%S')"
fi

# 获取当前分支名
current_branch=$(git symbolic-ref --short HEAD)

# 检查当前分支是否有远程上游分支
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)

echo "🚀 推送到 GitHub..."

if [ -z "$upstream" ]; then
  echo "ℹ️ 当前分支没有绑定远程分支，使用 --set-upstream 参数推送。"
  git push --set-upstream origin "$current_branch"
else
  git push
fi

echo "✅ 完成！Cloudflare Pages 将自动部署。"