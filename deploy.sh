#!/bin/bash
cd "$(dirname "$0")"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 日志文件
LOG_FILE="deploy.log"

log() {
  local msg="$1"
  echo -e "$msg"
  # 去掉颜色输出写入日志
  echo -e "$(echo -e "$msg" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')" >> "$LOG_FILE"
}

############################################
# 检查自身执行权限
############################################
log "${YELLOW}🔍 正在检查 deploy.sh 执行权限...${NC}"

perm=$(git ls-files --stage | grep deploy.sh | awk '{print $1}')

if [ "$perm" == "100755" ]; then
  log "${GREEN}✅ deploy.sh 已经有执行权限 (100755)${NC}"
else
  log "${RED}❌ deploy.sh 没有执行权限 (当前 $perm)${NC}"
  log "${YELLOW}⚙️ 正在修复...${NC}"
  chmod +x deploy.sh
  git add deploy.sh
  log "${GREEN}✅ 已修复，请记得提交: git commit -m 'fix: 确保 deploy.sh 可执行'${NC}"
fi

############################################
# 清理无用文件
############################################
log "${YELLOW}🧹 删除 .DS_Store 文件...${NC}"
find . -name ".DS_Store" -print -delete
git rm --cached -r .DS_Store 2>/dev/null

# 确保 .gitignore 中忽略
if ! grep -q "^.obsidian$" .gitignore 2>/dev/null; then
  echo ".obsidian" >> .gitignore
  log "${YELLOW}📄 已将 .obsidian 加入 .gitignore${NC}"
fi
if ! grep -q "^.DS_Store$" .gitignore 2>/dev/null; then
  echo ".DS_Store" >> .gitignore
  log "${YELLOW}📄 已将 .DS_Store 加入 .gitignore${NC}"
fi

git rm -r --cached .obsidian 2>/dev/null

############################################
# Git 用户信息
############################################
if ! git config user.name >/dev/null; then
  log "${YELLOW}⚙️ 设置 Git 用户名...${NC}"
  git config user.name "inkoml"
fi

if ! git config user.email >/dev/null; then
  log "${YELLOW}⚙️ 设置 Git 邮箱...${NC}"
  git config user.email "github@inkx.cc"
fi

############################################
# 同步远程 + 提交 + 推送
############################################
log "${YELLOW}🔄 正在同步远程仓库...${NC}"
if git pull --rebase origin main; then
  log "${GREEN}✅ 同步成功${NC}"
else
  log "${RED}❌ rebase 失败，尝试跳过或放弃...${NC}"
  git rebase --skip || git rebase --abort
fi

log "${YELLOW}📦 添加改动...${NC}"
git add .

timestamp=$(date +"%Y-%m-%d %H:%M:%S")
if git commit -m "内容更新：$timestamp"; then
  log "${GREEN}📝 提交成功：内容更新：$timestamp${NC}"
else
  log "${YELLOW}⚠️ 没有新改动可提交${NC}"
fi

log "${YELLOW}🚀 推送到 GitHub...${NC}"
if git push origin main; then
  log "${GREEN}✅ 推送成功，Cloudflare Pages 将自动部署${NC}"
else
  log "${RED}❌ 推送失败，请检查错误信息${NC}"
fi

# 写入部署完成时间
echo "----------------------------------------" >> "$LOG_FILE"
echo "部署完成时间：$(date +"%Y-%m-%d %H:%M:%S")" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo
read -p "按回车键退出..."
