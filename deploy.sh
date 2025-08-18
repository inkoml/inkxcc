#!/bin/bash
cd "$(dirname "$0")"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

############################################
# 检查执行权限
############################################
perm=$(git ls-files --stage | grep deploy.sh | awk '{print $1}')
if [ "$perm" != "100755" ]; then
  echo -e "${YELLOW}⚙️ 修复 deploy.sh 执行权限...${NC}"
  chmod +x deploy.sh
  git add deploy.sh
  echo -e "${GREEN}✅ deploy.sh 权限修复完成${NC}"
fi

############################################
# 清理无用文件
############################################
echo -e "${YELLOW}🧹 删除 .DS_Store 文件...${NC}"
find . -name ".DS_Store" -print -delete
git rm --cached -r .DS_Store 2>/dev/null

# 确保 .gitignore 中忽略 .obsidian、.DS_Store
for f in ".obsidian" ".DS_Store"; do
  if ! grep -q "^$f$" .gitignore 2>/dev/null; then
    echo "$f" >> .gitignore
    echo -e "${YELLOW}📄 已将 $f 加入 .gitignore${NC}"
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
# 自动 stash 所有修改
############################################
STASH_NAME="deploy-temp-$(date +%s)"
if ! git diff-index --quiet HEAD -- || ! git diff --cached --quiet; then
  echo -e "${YELLOW}📦 本地有修改，自动 stash 所有修改...${NC}"
  git stash push -u -m "$STASH_NAME"
  STASHED=true
else
  STASHED=false
fi

############################################
# 同步远程
############################################
echo -e "${YELLOW}🔄 同步远程仓库...${NC}"
if git pull --rebase origin main; then
  echo -e "${GREEN}✅ 同步成功${NC}"
else
  echo -e "${RED}❌ 同步失败，如果有冲突请手动解决${NC}"
fi

# 恢复本地 stash
if [ "$STASHED" = true ]; then
  echo -e "${YELLOW}📂 恢复本地修改...${NC}"
  git stash pop || echo -e "${RED}⚠️ 恢复时有冲突，请手动解决${NC}"
fi

############################################
# 添加改动
############################################
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

echo
read -p "按回车键退出..."
