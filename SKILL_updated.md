---
name: url-to-vault
description: >
  URL 하나를 입력받아 (웹 기사 또는 YouTube 링크) 콘텐츠를 자동으로 추출·분석·구조화한 뒤,
  Obsidian vault에 MECE 형식의 마크다운 노트로 저장하고,
  동일 내용의 비주얼 리포트 HTML을 생성해 GitHub Pages(wootom/news)에 배포하는 워크플로우 스킬.

  다음 상황에서 반드시 이 스킬을 사용하라:
  - 사용자가 https:// 또는 http:// URL을 입력했을 때
  - 사용자가 youtu.be 또는 youtube.com 링크를 입력했을 때
  - "정리해줘", "노트 만들어줘", "비주얼 리포트", "옵시디언에 저장" 등의 표현과 함께 URL이 제시될 때
  - URL 없이도 "최근 AI 뉴스 정리해줘" 처럼 콘텐츠 수집+정리+배포를 한 번에 요청할 때
---

# URL → Vault + Infographic + KakaoTalk 알림 자동화 스킬

## 환경 설정 (고정값)

```
Obsidian vault:       /Users/woojanghoon/Library/CloudStorage/GoogleDrive-woojanghoon@gmail.com/내 드라이브/obsidian_vault_2026/
노트 저장 폴더:        CLAUDE.md 참조 — YouTube → 10-Sources/YouTube/ | 기사 → 10-Sources/articles/
비주얼 리포트 경로:    /Users/woojanghoon/Sites/ai-infographic/    (이 폴더 = github.com/wootom/news repo 루트)
배포 인프라:          GitHub Pages — origin: github.com/wootom/news (main 브랜치 자동 발행)
외부 베이스 URL:      https://wootom.github.io/news/
  ※ 올바른 URL 예: https://wootom.github.io/news/2026-05-15-figure-f03-robot-collaboration.html
Telegram chat_id:     8378388303 (저장위치: ~/.vaax-telegram/chatid)
Bot Token:            8526353326:AAGuYBDDyOiZfQd4hbpHyIwGzvFK0_Bzqa4
Python 자막 도구:      youtube-transcript-api (pip install --break-system-packages)
```

**마운트 경로 (세션마다 변경됨 — 매 세션 시작 시 확인 필수)**
```bash
ls /sessions/   # 현재 세션 ID 확인
# 예: /sessions/funny-optimistic-dijkstra/
Obsidian vault:  /sessions/{세션ID}/mnt/obsidian_vault_2026/    ← 전체 vault 마운트
비주얼 리포트:    /sessions/{세션ID}/mnt/ai-infographic/         ← HTML 저장 + push 경로
vaax-telegram:   /sessions/{세션ID}/mnt/vaax-telegram/
```

> **⚠️ 배포 아키텍처**
> - HTML은 `mnt/ai-infographic/`에 직접 저장 (`~/Sites/ai-infographic/`와 동일한 위치)
> - 저장 완료 후 git commit + push → GitHub Pages가 1~2분 내 자동 재빌드
> - Netlify·rsync 일체 사용 안 함. wootom/news repo가 단일 외부 게시 채널

---

## Step 0 — 작업 폴더 마운트 (필수 선행)

**스킬 시작 시 가장 먼저 실행. 마운트 없이 파일을 저장하면 샌드박스에만 기록되고 Mac에 반영되지 않는다.**

### Step 0-A: Obsidian vault 마운트 (전체 vault)
```
request_cowork_directory(path="/Users/woojanghoon/Library/CloudStorage/GoogleDrive-woojanghoon@gmail.com/내 드라이브/obsidian_vault_2026")
→ VM 경로: /sessions/{세션ID}/mnt/obsidian_vault_2026/
```

### Step 0-B: 비주얼 리포트 / 웹 배포 폴더 마운트
```
request_cowork_directory(path="/Users/woojanghoon/Sites/ai-infographic")
→ VM 경로: /sessions/{세션ID}/mnt/ai-infographic/
```

### Step 0-C: 세션 ID 확인
```bash
ls /sessions/
```

마운트 후 `mnt/obsidian_vault_2026/`, `mnt/ai-infographic/` 디렉토리 존재 여부를 확인하고 Step 1로 진행.

---

## Step 1 — URL 유형 판별 및 콘텐츠 추출

### 웹 기사 URL인 경우
`WebFetch`로 전체 본문을 가져온다. 실패 시 관련 키워드로 `WebSearch`를 보완 검색한다.

### YouTube URL인 경우 (youtu.be / youtube.com/watch?v= / youtube.com/shorts/)
샌드박스 Python에서 `youtube_transcript_api`로 자막을 추출한다.

```python
from youtube_transcript_api import YouTubeTranscriptApi

# URL 유형별 video_id 파싱
# youtu.be/{id}  /  watch?v={id}  /  shorts/{id}
video_id = "XXXXXXXXXXX"

api = YouTubeTranscriptApi()
transcript_list = api.list(video_id)

# 한국어 우선, 없으면 영어
for lang in ['ko', 'en']:
    for t in transcript_list:
        if t.language_code.startswith(lang):
            data = t.fetch()
            # 타임스탬프 포함 전체 자막 보존 (소주제별 딥링크 생성에 활용)
            segments = [{"start": s.start, "text": s.text} for s in data]
            full_text = " ".join([s.text for s in data])
            break
```

패키지 미설치 시:
```bash
pip install youtube-transcript-api --break-system-packages -q
```

자막 추출 실패 시: 영상 설명란 + WebSearch로 보완.

#### YouTube 소주제별 타임스탬프 딥링크 (필수)

자막 세그먼트(`segments`)에서 각 소주제가 시작되는 시각(초)을 파악해 딥링크를 생성한다.

```python
# 소주제 시작 시각 파악 방법
# 1. 자막 세그먼트를 시간순으로 읽으며 주제 전환 지점 추정
# 2. 각 소주제 제목에 해당하는 첫 발화 세그먼트의 start 값 사용
# 3. 딥링크 형식: https://youtu.be/{video_id}?t={start_seconds}

def make_deeplink(video_id, start_seconds):
    return f"https://youtu.be/{video_id}?t={int(start_seconds)}"
```

- Obsidian 노트: 각 소주제 헤딩 옆에 `[▶ {MM:SS}](딥링크)` 형식으로 삽입
- 비주얼 리포트: 각 소주제 카드/섹션에 `▶ 영상 바로가기 (MM:SS)` 버튼 또는 링크 삽입
- 시각 표기: 초(int) → `MM:SS` 포맷 변환 (`f"{s//60}:{s%60:02d}"`)
- 타임스탬프 추출 불가 시: 딥링크 생략 후 `[타임스탬프 없음]` 표기

---

## Step 2 — MECE 구조화 분석

추출한 텍스트를 7개 축으로 MECE 분석한다. 각 축은 겹치지 않고 전체를 커버해야 한다.

| 번호 | 축 | YouTube 대체 |
|---|---|---|
| 1 | 핵심 개요 (테이블) | 동일 |
| 2 | 핵심 기능/내용 구조 | 동일 |
| 3 | 기술적 맥락 | 동일 |
| 4 | 전략적 의미 | 동일 |
| 5 | 경쟁 환경 비교표 | 핵심 워크플로우/방법론 |
| 6 | 활용 시나리오 (3개+) | 동일 |
| 7 | 현황 및 전망 | 동일 |

### 일반인 친화적 설명 원칙 (전 축 적용 필수)

분석한 모든 내용은 **해당 분야 비전문가(일반인)도 이해할 수 있는 언어**로 서술한다.

- **전문 용어 즉시 풀이**: 기술 용어가 등장하면 그 자리에서 쉬운 말로 정의 (예: "멀티모달 = 텍스트·이미지·영상 등 여러 형태의 정보를 동시에 처리하는 것")
- **비유/사례 활용**: 추상적 개념은 일상 사물이나 상황에 빗대어 설명 (예: "RAG는 시험 볼 때 참고서를 펼쳐 보는 것과 같습니다")
- **짧고 명확한 문장**: 한 문장에 하나의 개념만 담고, 복문보다 단문 선호
- **불필요한 약어 지양**: 약어 최초 사용 시 반드시 풀네임 병기 (예: "LLM(대규모 언어 모델)")
- **"왜 중요한가" 먼저**: 기능·구조 설명 전에 "이것이 왜 필요한가"를 한 줄로 먼저 제시
- **금지 패턴**: 전문 용어만 나열, 영문 약어 미설명, 추상적 단어(시너지·레버리지·패러다임) 무설명 사용

---

## Step 3 — Obsidian 마크다운 노트 저장

### 저장 경로 결정 (CLAUDE.md 참조 필수)

저장 전 반드시 vault의 CLAUDE.md를 읽어 올바른 경로를 결정한다:

```bash
cat "/sessions/{세션ID}/mnt/obsidian_vault_2026/CLAUDE.md"
```

CLAUDE.md의 폴더 구조 규칙:
- **YouTube 영상** → `10-Sources/YouTube/`
- **웹 기사** → `10-Sources/articles/`
- **개념 정리** → `20-Notes/AI/` (콘텐츠 성격에 따라 적합한 도메인 서브폴더 선택)

**파일 저장 경로 (bash 경로):**
```
YouTube: /sessions/{세션ID}/mnt/obsidian_vault_2026/10-Sources/YouTube/{파일명}.md
기사:    /sessions/{세션ID}/mnt/obsidian_vault_2026/10-Sources/articles/{파일명}.md
```

파일명 규칙: `{YYYY-MM-DD}-{주제 핵심 키워드}-{부제}.md`

**YAML frontmatter (CLAUDE.md 표준 준수):**
```yaml
---
title: {제목}
type: source
domain: personal
tags: [AI, {관련태그1}, {관련태그2}]
status: draft
created: {오늘날짜 YYYY-MM-DD}
updated: {오늘날짜 YYYY-MM-DD}
related: []
origin: "{원본 URL}"
---
```

**노트 하단 필수 섹션 2개:**
```markdown
## 비주얼 리포트
- 로컬: ~/Sites/ai-infographic/{YYYY-MM-DD}-{slug}.html
- 외부: https://wootom.github.io/news/{YYYY-MM-DD}-{slug}.html

## 출처
- [원본 제목](원본 URL)
- [참고 기사 제목](참고 기사 URL)
```

기존 파일이 있으면 Read 후 덮어쓴다.

---

## Step 4 — 비주얼 리포트 생성

**`visual-report` 스킬을 참조한다. 디자인 시스템·파일 규칙·검증 체크리스트는 해당 스킬에 정의되어 있으며, 여기서 중복 정의하지 않는다.**

### 이 스킬에서 결정하는 것
- 파일명 slug: 콘텐츠 핵심 키워드 2~4 단어, 영문 소문자 + 하이픈
- 형식: 기본 HTML (사용자가 PPT 요청 시 PPTX 추가 생성)
- 콘텐츠: Step 2의 MECE 7축 분석 결과를 비주얼 리포트 스킬에 전달

### 파일 저장 경로
```
HTML:  /sessions/{세션ID}/mnt/ai-infographic/{YYYY-MM-DD}-{slug}.html
PPTX:  /sessions/{세션ID}/mnt/ai-infographic/{YYYY-MM-DD}-{slug}.pptx  (요청 시)
```

> ⚠️ **이 단계에서는 파일만 저장한다. 배포는 Step 6에서 일괄 처리.**
> Step 5(index.html 갱신)가 끝나야 git push에 포털 변경분이 함께 포함된다.

---

## Step 5 — index.html 포털 갱신

**반드시 기존 index.html을 먼저 Read한 뒤 새 항목을 추가해 덮어쓴다. Read 없이 새로 작성하면 기존 항목이 전부 삭제된다.**

index.html 경로: `/sessions/{세션ID}/mnt/ai-infographic/index.html`

기존 파일이 없을 경우에만 새로 생성한다. 있을 경우 기존 항목을 모두 보존하고 맨 위에 새 항목 추가 (최신순):
```html
<div class="item">
  <span class="date-pill">YYYY-MM-DD</span>
  <a href="./{YYYY-MM-DD}-{slug}.html">{제목}</a>
</div>
```

> 이 단계 또한 파일만 갱신한다. 실제 외부 노출은 Step 6의 단일 git push로 일괄 처리된다.

---

## Step 6 — GitHub Pages 배포 + 200 검증 (필수)

Step 4·5에서 저장·갱신한 파일을 `~/Sites/ai-infographic` 작업 트리(= `github.com/wootom/news` repo)에서
한 번에 commit·push한다. main 브랜치가 `https://wootom.github.io/news/` 의 배포 소스다.

### 6-A: git push

```bash
cd /sessions/{세션ID}/mnt/ai-infographic

# 1) 신규 HTML + index.html 변경분을 일괄 정리 (D + ?? 페어가 M으로 자연스럽게 합쳐짐)
git add -A

# 2) 커밋 (slug + 날짜) — index.html 변경분도 같은 커밋에 포함됨
SLUG="{YYYY-MM-DD}-{slug}"
git commit -m "update: ${SLUG}"

# 3) push (origin/main → GitHub Pages 자동 빌드)
git push origin main
```

push 실패 시 진단 순서:
1. `git status` — lock 파일(`.git/index.lock`, `.git/HEAD.lock`)이 남아있으면 삭제 후 재시도
2. `git remote -v` — origin이 `github.com/wootom/news.git`인지 확인
3. 인증 실패면 PAT 만료. 회전 후 `git remote set-url`로 재등록 (PAT을 URL에 박지 말고 macOS keychain 사용 권장)

### 6-B: 200 검증 게이트 (Step 7 발송 전 필수)

GitHub Pages는 push 후 30~90초 내 재빌드된다. 다음 명령으로 실제 200 응답이 올 때까지 대기한 뒤
Step 7(카톡 알림 발송)으로 진행한다. **404 상태로 알림을 발송하면 라이브 채팅방에 dead link가 노출된다.**

```bash
SLUG="{YYYY-MM-DD}-{slug}"
URL="https://wootom.github.io/news/${SLUG}.html"
until [ "$(curl -s -o /dev/null -w "%{http_code}" "$URL")" = "200" ]; do
  echo "waiting Pages rebuild..."
  sleep 10
done
echo "OK: $URL"
```

기다리는 동안 5분(=30회) 초과면 GitHub Actions Pages 빌드 실패를 의심하고
`gh run list --repo wootom/news --limit 3`으로 빌드 상태를 점검한다.

검증을 통과하지 못한 경우 Step 7로 진행 금지. 빌드 실패 원인을 해결해 200을 받은 뒤 알림 발송.

---

## Step 7 — KakaoTalk 알림 발송

Step 6의 200 검증 게이트를 통과한 뒤에만 텔레그램 봇을 경유해 카카오톡 VAAX 방으로 알림을 보낸다.
게이트 미통과 상태에서 이 단계를 실행하면 라이브 채팅방에 dead link가 노출된다.

### 아키텍처
```
Claude (샌드박스) → Telegram Bot API (@vaax_fovea_bot, chat_id: 8378388303)
  → vaax-telegram 릴레이 (Mac mini 상시 실행)
  → KakaoTalk VAAX 방 (vaaxbot이 telegram_listener를 통해 다중 forward)
```

### 알림 발송 코드 (샌드박스에서 직접 실행)

```python
import json, urllib.request

BOT_TOKEN = "8526353326:AAGuYBDDyOiZfQd4hbpHyIwGzvFK0_Bzqa4"
chat_id = "8378388303"
MAX_CHARS = 390

title = "{비주얼 리포트 제목}"
bullets = [
    "{핵심 요약 1}",
    "{핵심 요약 2}",
    "{핵심 요약 3}",
    "{핵심 요약 4}",
]
url = "https://wootom.github.io/news/{YYYY-MM-DD}-{slug}.html"
date = "{YYYY-MM-DD}"

lines = [f"[AI 비주얼 리포트] {date}", title, ""]
for b in bullets:
    lines.append(f"- {b}")
lines += ["", url]
msg = "\n".join(lines)

# 400자 초과 시 bullet 3개·50자로 줄임
if len(msg) > MAX_CHARS:
    lines = [f"[AI 비주얼 리포트] {date}", title, ""]
    for b in bullets[:3]:
        lines.append(f"- {b[:50]}{'…' if len(b) > 50 else ''}")
    lines += ["", url]
    msg = "\n".join(lines)[:MAX_CHARS]

payload = json.dumps({"chat_id": chat_id, "text": msg}).encode("utf-8")
req = urllib.request.Request(
    f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=10) as resp:
    result = json.loads(resp.read().decode("utf-8"))
    if result.get("ok"):
        print(f"[OK] 카카오톡 알림 발송 완료 ({len(msg)}자)")
    else:
        print(f"[FAIL] {result}")
```

---

## Step 8 — 완료 보고

```
완료

Obsidian: 10-Sources/YouTube/{파일명}.md  (또는 10-Sources/articles/)
비주얼 리포트: https://wootom.github.io/news/{YYYY-MM-DD}-{slug}.html
카카오톡: VAAX 알림 발송 완료 ({N}자)

핵심 내용:
- {요약 1}
- {요약 2}
- {요약 3}

출처:
- [{원본 제목}]({원본 URL})
```

---

## 주의사항

- Bash 샌드박스는 Mac 파일시스템 직접 접근 불가 → 반드시 Step 0 마운트 후 마운트 경로 사용
- **Obsidian 실제 폴더 구조**: `10-Sources/YouTube/`, `10-Sources/articles/`, `20-Notes/AI/` — CLAUDE.md를 읽어 결정, 하드코딩 금지
- HTML은 `mnt/ai-infographic/`에 직접 저장 (별도 비주얼 리포트 폴더 마운트 불필요)
- HTML 저장 후 반드시 Step 6의 git push 실행 → 미실행 시 외부 URL은 404
- **카톡 알림 발송(Step 7) 전 Step 6-B 200 검증 게이트 통과 필수** — 라이브 채팅방 dead link 방지
- 마운트 경로의 세션 ID는 매 세션 변경됨 → `ls /sessions/` 로 확인
- index.html 갱신 전 반드시 기존 파일 Read → 기존 항목 보존 후 최신 항목 맨 위 추가
- 비주얼 리포트는 텍스트 나열 금지 — 도식(흐름도·비교표·파이프라인) 형태 필수
- index.html 링크는 `./` 상대경로 필수 (절대경로 금지)
- youtube-transcript-api 미설치 시 pip 설치 후 재시도
- WebFetch 실패 시 WebSearch 보완 검색 후 종합
- **YouTube 콘텐츠**: 소주제별 타임스탬프 딥링크 필수 — 누락 시 결과물 재작성
- **모든 콘텐츠**: 전문 용어 즉시 풀이 + 비유 사용 — 일반인 기준으로 이해 가능해야 함
- **외부 게시 채널은 GitHub Pages(`wootom.github.io/news`) 단일 채널** — Netlify·다른 호스팅 일체 사용 금지
- GitHub PAT을 git remote URL에 평문으로 박지 말 것 (이미 박혀 있으면 회전 후 keychain credential helper로 분리)
