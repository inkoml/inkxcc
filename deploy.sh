#!/bin/bash
cd "$(dirname "$0")"

# 设置 VPN 代理（可选，若不需要可注释掉）
export https_proxy=http://127.0.0.1:1080
export http_proxy=http://127.0.0.1:1080
export all_proxy=socks5://127.0.0.1:1080

# 确保 Git 用户信息已设置
if ! git config user.name >/dev/null; then
  echo "设置 Git 用户名"
  git config user.name "inkoml"
fi

if ! git config user.email >/dev/null; then
  echo "设置 Git 邮箱"
  git config user.email "github@inkx.cc"
fi

# 添加 .gitignore 中忽略 .obsidian
if ! grep -q "^.obsidian$" .gitignore 2>/dev/null; then
  echo ".obsidian" >> .gitignore
fi

# 从 Git 跟踪中移除 .obsidian（如果之前已跟踪）
git rm -r --cached .obsidian 2>/dev/null

# 添加所有更改
echo "📦 添加其他改动..."
git add .

# 提交改动
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
echo "📝 提交中：内容更新：$timestamp"
git commit -m "内容更新：$timestamp"

# 推送到 GitHub
echo "🚀 推送到 GitHub..."
git push

echo "✅ 完成！Cloudflare Pages 将自动部署。"

# 防止终端窗口关闭（Windows Git Bash 专用）
echo
read -p "按回车键退出..."
