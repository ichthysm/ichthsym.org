---
description: CODA 시스템의 명령어, 훅, 에이전트, 워크플로우를 알고 싶을 때. 사용자가 CODA 사용법을 물어보면 호출.
---

# CODA 도움말

**Arguments**에 따라 해당 reference 파일을 읽어서 출력합니다:

| Arguments | 참조 파일 |
|-----------|-----------|
| (없음) | 아래 기본 개요 출력 |
| `명령어` / `commands` | `tools/coda/references/help-commands.md` |
| `훅` / `hooks` | `tools/coda/references/help-hooks.md` |
| `에이전트` / `agents` | `tools/coda/references/help-agents.md` |
| `워크플로우` / `workflow` | `tools/coda/references/help-workflow.md` |

## 출력 로직

1. Arguments를 파싱
2. 매칭되는 reference 파일을 Read 도구로 읽기
3. 내용을 그대로 출력

## 기본 개요 (Arguments 없음)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 CODA - Claude Orchestrated Dev Automation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 슬래시 커맨드 (13개)
  /초기화 /새프로젝트 /상태저장 /상태복원 /버전업
  /병렬작업 /자율개발 /자율결과 /최종검수
  /개발환경 /프론트가이드 /인사이트 /coda-help

🪝 자동 훅 (5개)
  session-context-loader  - 세션 시작 시 버전/상태 주입
  keyword-detector        - 키워드 감지 → 프로토콜 주입
  pre-tool-guard          - 보호 파일 수정 차단
  pre-commit-check        - git commit 전 tsc 체크
  stop-verifier           - 세션 종료 시 미저장 확인

👥 에이전트 (9명)
  정하윤 (PM, opus)          박안도 (Backend, sonnet)
  유아이 (Frontend, sonnet)  배포준 (DevOps, sonnet)
  Chloe (Security, opus)     나검수 (QA, sonnet)
  문서인 (Docs, sonnet)      이지표 (Data, sonnet)
  송대시 (Viz, sonnet)

📖 상세 도움말
  /coda-help 명령어      /coda-help 훅
  /coda-help 에이전트    /coda-help 워크플로우

🔧 설치: bash install.sh --update
📂 위치: ~/.claude/commands/ | ~/.claude/hooks/ | .claude/agents/
```

## 함정 (Pitfalls)

- **install.sh --update 후 세션 재시작 필요** — hooks 경로가 settings.json에 하드코딩
- **에이전트는 프로젝트 레벨** (`.claude/agents/`), 커맨드는 유저 레벨 (`~/.claude/commands/`)
- **coda.config.json 없으면 기본값 사용** — Layer 2 체크 비활성화 상태
