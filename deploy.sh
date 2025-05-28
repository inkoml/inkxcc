#!/bin/bash

# vpn
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890

# 自动生成提交信息（当前日期）
commit_msg="内容更新：$(date '+%Y-%m-%d %H:%M:%S')"

echo "📦 添加改动..."
git add .

echo "📝 提交中：$commit_msg"
git commit -m "$commit_msg"

echo "🚀 推送到 GitHub..."
git push

echo "✅ 完成！Cloudflare Pages 将自动部署。"
