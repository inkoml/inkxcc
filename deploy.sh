#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<'USAGE'
Usage: ./deploy.sh [--all] [--dry-run] [--no-push]

  --all      Stage all changes automatically (git add -A).
  --dry-run  Only run safety checks and Hugo build, then exit.
  --no-push  Commit staged changes but skip git push.
USAGE
}

STAGE_ALL=false
DRY_RUN=false
NO_PUSH=false

while (($# > 0)); do
  case "$1" in
    --all)
      STAGE_ALL=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --no-push)
      NO_PUSH=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Unknown argument: $1${NC}"
      usage
      exit 1
      ;;
  esac
  shift
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo -e "${RED}❌ Not inside a git repository${NC}"
  exit 1
fi

BRANCH=$(git branch --show-current)
if [[ "$BRANCH" != "main" ]]; then
  echo -e "${RED}❌ Current branch is '$BRANCH'. Switch to main before deploy.${NC}"
  exit 1
fi

if [ -f .gitmodules ]; then
  DIRTY_SUBMODULES="$(
    git submodule foreach --recursive \
      'if ! git diff --quiet || ! git diff --cached --quiet; then echo "$name"; fi' \
      2>/dev/null | sed '/^Entering /d'
  )"
  if [[ -n "$DIRTY_SUBMODULES" ]]; then
    echo -e "${RED}❌ Dirty submodule(s) detected:${NC}"
    echo "$DIRTY_SUBMODULES"
    exit 1
  fi
fi

if [[ "$STAGE_ALL" == true ]]; then
  echo -e "${YELLOW}📦 Staging all changes (git add -A)...${NC}"
  git add -A
fi

UNSTAGED=$(git diff --name-only)
UNTRACKED=$(git ls-files --others --exclude-standard)

if [[ "$DRY_RUN" != true ]]; then
  # Conservative safety gate: no unstaged or untracked changes allowed.
  if [[ -n "${UNSTAGED}" || -n "${UNTRACKED}" ]]; then
    echo -e "${RED}❌ Working tree is not clean.${NC}"
    echo -e "${YELLOW}Only staged changes are allowed for deploy.${NC}"
    [[ -n "${UNSTAGED}" ]] && echo -e "${YELLOW}Unstaged files:${NC}\n${UNSTAGED}"
    [[ -n "${UNTRACKED}" ]] && echo -e "${YELLOW}Untracked files:${NC}\n${UNTRACKED}"
    exit 1
  fi

  if git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️ No staged changes to commit. Stage files first.${NC}"
    exit 1
  fi
elif [[ -n "${UNSTAGED}" || -n "${UNTRACKED}" ]]; then
  echo -e "${YELLOW}ℹ️ Dry run ignores git cleanliness checks.${NC}"
fi

echo -e "${YELLOW}🔎 Running Hugo build check...${NC}"
hugo --gc --minify

echo -e "${GREEN}✅ Build passed${NC}"

if [[ "$DRY_RUN" == true ]]; then
  echo -e "${GREEN}✅ Dry run complete${NC}"
  exit 0
fi

timestamp=$(date +"%Y-%m-%d %H:%M:%S")
msg="内容更新：${timestamp}"

echo -e "${YELLOW}📝 Creating commit from staged changes...${NC}"
git commit -m "$msg"
echo -e "${GREEN}✅ Commit created: $msg${NC}"

if [[ "$NO_PUSH" == true ]]; then
  echo -e "${YELLOW}⏭️ Skip push (--no-push)${NC}"
  exit 0
fi

echo -e "${YELLOW}🔄 Rebase with latest origin/${BRANCH}...${NC}"
git pull --rebase origin "$BRANCH"

echo -e "${YELLOW}🚀 Pushing to origin/${BRANCH}...${NC}"
git push origin "$BRANCH"
echo -e "${GREEN}✅ Push completed${NC}"
