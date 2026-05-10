#!/bin/bash
# AI 비주얼 리포트 자동 배포 설정 (최초 1회 실행)
# Finder에서 더블클릭하면 자동으로 Terminal에서 실행됩니다.

set -e

SOURCE="$HOME/Documents/Claude/Projects/URL 요약공유"
DEST="$HOME/Sites/ai-infographic"
SCRIPT="$SOURCE/.sync-to-sites.sh"
PLIST="$HOME/Library/LaunchAgents/com.woojanghoon.ai-infographic-sync.plist"

echo "=== AI 비주얼 리포트 자동 배포 설정 ==="
echo ""

# 1. 기존 Sites/ai-infographic 파일을 URL 요약공유로 복사 (누락된 파일 병합)
echo "[1/4] 기존 HTML 파일 병합 중..."
cp -n "$DEST"/*.html "$SOURCE/" 2>/dev/null && echo "  기존 파일 복사 완료" || echo "  (복사할 파일 없음)"

# 2. sync 스크립트에 실행 권한 부여
echo "[2/4] sync 스크립트 권한 설정 중..."
chmod +x "$SCRIPT"
echo "  완료: $SCRIPT"

# 3. launchd plist 생성
echo "[3/4] launchd 감시자 생성 중..."
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.woojanghoon.ai-infographic-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$SOURCE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
echo "  완료: $PLIST"

# 4. launchd 에이전트 로드 (이미 로드된 경우 언로드 후 재로드)
echo "[4/4] launchd 에이전트 활성화 중..."
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "  완료"

# 5. 즉시 동기화 실행 (현재 파일 배포)
echo ""
echo "즉시 동기화 실행 중..."
bash "$SCRIPT"
echo "동기화 완료"

echo ""
echo "==============================="
echo "설정 완료!"
echo "이제부터 URL 요약공유 폴더에 HTML 파일을"
echo "저장하면 자동으로 웹서버에 반영됩니다."
echo ""
ls "$DEST"/*.html 2>/dev/null | xargs -I{} basename {} | sort -r | head -10
echo "==============================="
echo ""
read -p "엔터를 누르면 창이 닫힙니다..."
