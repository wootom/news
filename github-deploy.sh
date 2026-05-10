#!/bin/bash
# ── github-deploy.sh ───────────────────────────────────
# ai-infographic → GitHub Pages (wootom/news) 배포 스크립트
# 사용법: bash ~/Sites/ai-infographic/github-deploy.sh [slug]
#   예시: bash ~/Sites/ai-infographic/github-deploy.sh 2026-05-07-ai-news
# ──────────────────────────────────────────────────────

GITHUB_USER="wootom"
REPO_NAME="news"
DIR="$HOME/Sites/ai-infographic"
SLUG="${1:-}"

cd "$DIR" || { echo "❌ $DIR 없음"; exit 1; }

git add .
COMMIT_MSG="update: ${SLUG:-$(date +%Y-%m-%d)}"
git commit -m "$COMMIT_MSG" 2>/dev/null || echo "[skip] 변경사항 없음"
git push origin main

if [ -n "$SLUG" ]; then
  echo "[GitHub Pages] 배포 완료 → https://$GITHUB_USER.github.io/$REPO_NAME/${SLUG}.html"
else
  echo "[GitHub Pages] 배포 완료 → https://$GITHUB_USER.github.io/$REPO_NAME/"
fi
