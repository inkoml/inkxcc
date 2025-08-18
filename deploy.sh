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
  # 去掉颜色写入日志
  echo -e "$(echo -e "$msg" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')" >> "$LOG_FILE"
}

############################################
# 检查执行权限
############################################
perm=$(git ls-files --stage | grep deploy.sh | awk '{print $1}')
if [ "$perm" != "100755" ]; then
  log "${YELLOW}⚙️ 修复 deploy.sh 执行权限...${NC}"
  chmod +x deploy.sh
  git add deploy.sh
  log "${GREEN}✅ deploy.sh 权限修复完成${NC}"
fi

############################################
# 清理无用文件
############################################
log "${YELLOW}🧹 删除 .DS_Store 文件...${NC}"
find . -name ".DS_Store" -print -delete
git rm --cached -r .DS_Store 2>/dev/null

# 确保 .gitignore 中忽略 .obsidian 和 deploy.log
for f in ".obsidian" "deploy.log"; do
  if ! grep -q "^$f$" .gitignore 2>/dev/null; then
    echo "$f" >> .gitignore
    log "${YELLOW}📄 已将 $f 加入 .gitignore${NC}"
  fi
done

git rm -r --cached .obsidian 2>/dev/null

############################################
# Git 用户信息
############################################
if ! git config user.name >/dev/null; then
  git config user.name "inkoml"
fi
if ! git config user.email >/dev/null; then
  git config user.email "github@inkx.cc"
fi

############################################
# 自动 stash 本地修改（包括已暂存文件），排除 deploy.log
############################################
STASH_NAME="deploy-temp-$(date +%s)"
if ! git diff-index --quiet HEAD -- || ! git diff --cached --quiet; then
  log "${YELLOW}📦 本地有未暂存或已暂存修改，自动 stash（排除 deploy.log）...${NC}"
  git stash push -u -m "$STASH_NAME" -- ':!deploy.log'
  STASHED=true
else
  STASHED=false
fi

############################################
# 同步远程
############################################
log "${YELLOW}🔄 同步远程仓库...${NC}"
if git pull --rebase origin main; then
  log "${GREEN}✅ 同步成功${NC}"
else
  log "${RED}❌ 同步失败，如果有冲突请手动解决${NC}"
fi

# 恢复本地 stash
if [ "$STASHED" = true ]; then
  log "${YELLOW}📂 恢复本地修改...${NC}"
  git stash pop || log "${RED}⚠️ 恢复时有冲突，请手动解决${NC}"
fi

############################################
# 添加改动
############################################
log "${YELLOW}📦 添加改动...${NC}"
git add .

# 提交改动
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
if git commit -m "内容更新：$timestamp"; then
  log "${GREEN}📝 提交成功：内容更新：$timestamp${NC}"
else
  log "${YELLOW}⚠️ 没有新改动可提交${NC}"
fi

# 推送到 GitHub
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
