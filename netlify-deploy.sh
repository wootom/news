#!/bin/bash
# netlify-deploy.sh
# 첫 실행 시 Netlify 사이트 자동 생성 → ID 저장 → 배포
# 이후 실행 시 저장된 ID로 바로 배포

# ── 유일하게 필요한 설정 ─────────────────────────────────────
NETLIFY_AUTH_TOKEN="nfp_6vUcFn4XUKgxVm9Zmy25d9pLuCrXGTgLc63b"
# ────────────────────────────────────────────────────────────

SITE_ID_FILE="$HOME/.vaax-netlify-site"   # site_id, url 저장
DIR="$HOME/Sites/ai-infographic"
ZIPFILE="/tmp/ai-infographic-$(date +%s).zip"
SLUG="${1:-}"

# ── 사이트 ID 로드 or 최초 생성 ─────────────────────────────
if [ ! -f "$SITE_ID_FILE" ]; then
  echo "[Netlify] 첫 실행 — 사이트 자동 생성 중..."
  RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $NETLIFY_AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"vaax-infographic"}' \
    "https://api.netlify.com/api/v1/sites")

  if echo "$RESPONSE" | grep -q '"errors"'; then
    # 이름 충돌 시 이름 없이 재시도 (랜덤 이름 자동 부여)
    RESPONSE=$(curl -s -X POST \
      -H "Authorization: Bearer $NETLIFY_AUTH_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{}' \
      "https://api.netlify.com/api/v1/sites")
  fi

  SITE_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  SITE_URL=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['ssl_url'])")

  printf "%s\n%s\n" "$SITE_ID" "$SITE_URL" > "$SITE_ID_FILE"
  echo "[Netlify] 사이트 생성 완료: $SITE_URL"
fi

NETLIFY_SITE_ID=$(sed -n '1p' "$SITE_ID_FILE")
SITE_BASE_URL=$(sed -n '2p' "$SITE_ID_FILE")

# ── HTML 전체 zip → 배포 ─────────────────────────────────────
cd "$DIR" || exit 1
zip -q "$ZIPFILE" *.html

RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $NETLIFY_AUTH_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary "@$ZIPFILE" \
  "https://api.netlify.com/api/v1/sites/$NETLIFY_SITE_ID/deploys")

rm -f "$ZIPFILE"

STATE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('state','error'))" 2>/dev/null)
if [ "$STATE" = "error" ] || [ -z "$STATE" ]; then
  echo "[Netlify ERROR] $(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error_message') or d.get('message','unknown'))" 2>/dev/null)"
  exit 1
fi

if [ -n "$SLUG" ]; then
  echo "[Netlify] 배포 완료: ${SITE_BASE_URL}/${SLUG}.html"
else
  echo "[Netlify] 배포 완료: ${SITE_BASE_URL}"
fi
