#!/bin/bash
# URL 요약공유 → ~/Sites/ai-infographic/ 자동 동기화 스크립트
# launchd WatchPaths 에 의해 트리거됨

SOURCE="$HOME/Documents/Claude/Projects/URL 요약공유"
DEST="$HOME/Sites/ai-infographic"

# HTML 파일만 복사 (숨김 파일·md·기타 제외)
rsync -a --include="*.html" --exclude="*" "$SOURCE/" "$DEST/"
