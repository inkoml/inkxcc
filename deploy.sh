#!/bin/bash
cd "$(dirname "$0")"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 删除所有 .DS_Store 文件
echo -e "${YELLOW}🧹 删除 .DS_Store 文件...${NC}"
find . -name ".DS_Store" -print -delete
git rm --cached -r .DS_Store 2>/dev/null

# 设置 VPN 代理（可选，若不需要可注释掉）
export https_proxy=http://127.0.0.1:1080
export http_proxy=http://127.0.0.1:1080
export all_proxy=socks5://127.0.0.1:1080

# 确保 Git 用户信息已设置
if ! git config user.name >/dev/null; then
  echo -e "${YELLOW}⚙️ 设置 Git 用户名...${NC}"
  git config user.name "inkoml"
fi

if ! git config user.email >/dev/null; then
  echo -e "${YELLOW}⚙️ 设置 Git 邮箱...${NC}"
  git config user.email "github@inkx.cc"
fi

# 确保 .gitignore 中忽略不需要的文件
if ! grep -q "^.obsidian$" .gitignore 2>/dev/null; then
  echo ".obsidian" >> .gitignore
  echo -e "${YELLOW}📄 已将 .obsidian 加入 .gitignore${NC}"
fi
if ! grep -q "^.DS_Store$" .gitignore 2>/dev/null; then
  echo ".DS_Store" >> .gitignore
  echo -e "${YELLOW}📄 已将 .DS_Store 加入 .gitignore${NC}"
fi

# 从 Git 跟踪中移除 .obsidian（如果之前已跟踪）
git rm -r --cached .obsidian 2>/dev/null

# 拉取远程更新并 rebase
echo -e "${YELLOW}🔄 正在同步远程仓库...${NC}"
if git pull --rebase origin main; then
  echo -e "${GREEN}✅ 同步成功${NC}"
else
  echo -e "${RED}❌ rebase 失败，尝试跳过或放弃...${NC}"
  git rebase --skip || git rebase --abort
fi

# 添加所有更改
echo -e "${YELLOW}📦 添加改动...${NC}"
git add .

# 提交改动
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
if git commit -m "内容更新：$timestamp"; then
  echo -e "${GREEN}📝 提交成功：内容更新：$timestamp${NC}"
else
  echo -e "${YELLOW}⚠️ 没有新改动可提交${NC}"
fi

# 推送到 GitHub
echo -e "${YELLOW}🚀 推送到 GitHub...${NC}"
if git push origin main; then
  echo -e "${GREEN}✅ 推送成功，Cloudflare Pages 将自动部署${NC}"
else
  echo -e "${RED}❌ 推送失败，请检查错误信息${NC}"
fi

# 防止终端窗口关闭（Windows Git Bash 专用）
echo
read -p "按回车键退出..."
