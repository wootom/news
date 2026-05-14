---
tags: [AI, Claude, OpenSource, CodingAgent, LLM]
date: 2026-04-20
source: https://news.hada.io/topic?id=28115
type: Article
---

# OpenClaude — Claude Code 소스 유출 기반 멀티모델 코딩 에이전트

## 1. 핵심 개요

| 항목 | 내용 |
|---|---|
| 프로젝트명 | OpenClaude |
| 기원 | Claude Code npm 소스맵 의도치 않게 포함 → 소스코드 노출 (2026-03-31) |
| 핵심 가치 | Claude Code 도구셋 그대로 + GPT-4o·Gemini·Ollama 등 멀티모델 지원 |
| 현재 위상 | 22.8k stars, 7.7k forks, 86명 기여자, MIT 라이선스 |
| 설치 | `npm install -g @gitlawb/openclaude` |

## 2. 핵심 기능 구조

- **백엔드 교체**: 환경변수 3줄로 OpenAI/Gemini/Ollama 등 즉시 전환
- **도구셋 유지**: Bash, 파일 R/W/E, grep, glob, agents, tasks, MCP 전부 보존
- **에이전트 라우팅**: 작업별 최적 모델 자동 배정 (Explore→DeepSeek, Plan→GPT-4o)
- **부가 기능**: VS Code 확장 내장, gRPC 헤드리스 서버, Firecrawl 웹검색

## 3. 기술적 맥락

- npm 소스맵이 빌드 과정에서 패키지에 의도치 않게 포함된 것이 원인
- TypeScript + Bun 기반 빌드, OpenAI Chat Completions API 호환 레이어로 구현
- `~/.claude/settings.json`의 `agentRouting` 설정으로 모델별 역할 분리 가능
- v0.5.2 (2026-04-20) 기준 83개 이슈, 67개 PR 처리 중

## 4. 전략적 의미

- Anthropic의 Claude Code 독점 포지션 사실상 무력화
- AI 에이전트 CLI 시장의 멀티모델 경쟁 가속화 트리거
- Anthropic 상표권·저작권 법적 조치 가능성 내재
- 7.7k 포크로 완전 차단 사실상 불가능

## 5. 경쟁 환경 비교

| | Claude Code | OpenClaude | Aider | Continue.dev |
|---|---|---|---|---|
| 지원 모델 | Claude 전용 | 멀티모델 | 멀티모델 | 멀티모델 |
| 도구셋 | 풍부 (MCP, agents) | 동일 수준 | 제한적 | IDE 중심 |
| 라이선스 | 독점 | MIT | Apache | Apache |
| 법적 지위 | 공식 | 그레이존 | 합법 | 합법 |
| 설치 난이도 | 쉬움 | 쉬움 | 중간 | 쉬움 |

## 6. 활용 시나리오

- **비용 최적화**: DeepSeek V3·GPT-4o mini로 교체 시 Claude 대비 ~90% 비용 절감
- **완전 로컬 실행**: Ollama + qwen2.5-coder로 인터넷·API 키 없이 사용
- **에이전트 라우팅**: 단순 탐색→저비용 모델, 복잡 계획→고성능 모델 자동 분배

## 7. 현황 및 전망

- 3주 만에 22.8k stars 달성 → AI 오픈소스 역대 최단기 성장 사례 중 하나
- GeekNews 커뮤니티: "훔친 걸 훔쳐서 훔치고" 등 법적 우려와 기술 완성도 공존
- 전망: Anthropic 법적 조치 시 대응 불투명, 다수 포크로 완전 차단 어려울 것

## 비주얼 리포트
- 로컬: /sessions/focused-blissful-davinci/mnt/URL 요약공유/2026-04-20-openclaude-claude-code-leak.html
- 외부: https://wootom.github.io/news/2026-04-20-openclaude-claude-code-leak.html

## 출처
- [Claude Code 소스 유출로 탄생한 OpenClaude — GPT-4o, Gemini | GeekNews](https://news.hada.io/topic?id=28115)
- [OpenClaude GitHub](https://github.com/Gitlawb/openclaude)
