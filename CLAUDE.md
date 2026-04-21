# CLAUDE.md

이 파일은 이 저장소에서 코드 작업을 할 때 Claude Code (claude.ai/code)에게 가이드를 제공합니다.

## 프로젝트 개요

**ICHTHYS SOLACE**는 선교사 심리치유, 탈북 고아 돌봄, 외국인 사역을 중심으로 하는 신앙 기반 사역 단체의 디지털 플랫폼입니다. 현재는 정적 HTML 사이트(`Mobile/`)만 존재하며, `Web/` 디렉토리는 향후 웹 애플리케이션 개발을 위해 예약된 상태입니다.

## 디렉토리 구조

```
ICHTHYS_SOLACE/
├── Mobile/          # 현재 활성 사이트 (정적 HTML)
│   └── index.html   # 단일 페이지 앱 — 인라인 CSS 포함
├── Web/             # 향후 웹 앱 (현재 비어 있음)
└── coda/            # CODA 개발 자동화 시스템 (메타 프레임워크)
```

## 명령어

`Web/` 개발이 시작되면 `package.json`이 생성될 예정이며, CODA 설정 기준 명령어는 아래와 같습니다:

```bash
pnpm install    # 의존성 설치
pnpm dev        # 개발 서버 실행
pnpm build      # 프로덕션 빌드
pnpm test       # 테스트 실행
pnpm lint       # 린트 실행
```

`Mobile/`은 빌드 도구 없이 브라우저에서 직접 열면 됩니다.

## Mobile 사이트 아키텍처

`Mobile/index.html`은 외부 파일 없는 **단일 파일 구조**입니다:

- **레이아웃**: 섹션 순서 — Hero → About → Vision → Ministry → Contact
- **반응형 분기점**: `768px` (모바일 우선)
- **스크롤**: `scroll-behavior: smooth` + 네비게이션 링크로 섹션 앵커 연결
- **디자인 시스템**:
  - 크림 배경: `#faf8f5`
  - 올리브 주조색: `#4a5240`
  - 다크 텍스트: `#1a1a1a`
  - 폰트: `Playfair Display` (헤딩), `Noto Sans KR` / `Noto Serif KR` (본문)
- **이미지**: `img/` 폴더 로컬 참조, `sample/` 폴더에 샘플 이미지

## CODA 시스템

`coda/` 디렉토리는 **Claude Orchestrated Development Automation** 메타 프레임워크입니다. 이 저장소의 개발 워크플로우 전체를 관리합니다.

### 핵심 개념

- **에이전트 페르소나**: `coda/agents/`에 9개 전문 역할 정의 (PM 정하윤, Backend 박안도, Frontend 유아이 등)
- **커스텀 커맨드**: `coda/commands/`에 슬래시 커맨드 정의 — `/상태저장`, `/상태복원`, `/자율개발`, `/최종검수` 등
- **훅**: `coda/hooks/`에 세션 시작/종료, 툴 실행 가드 자동화
- **버전 관리**: `coda/VERSION` (현재 `1.4.0`) + `coda.config.json`으로 빌드 명령 중앙 관리

### 주요 CODA 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/상태저장` | 세션 종료 전 `PROJECT_STATUS.md` 업데이트 |
| `/상태복원` | 새 세션에서 이전 작업 컨텍스트 복원 |
| `/자율개발` | 대규모 작업 무인 자율 실행 |
| `/최종검수` | 머지 전 빌드/테스트/코드품질 9단계 검증 |
| `/버전업` | 커밋 전 VERSION + package.json 버전 동기화 |

### 세션 상태

`PROJECT_STATUS.md`가 작업 진행 상황의 단일 진실 공급원입니다. 새 세션 시작 시 반드시 이 파일을 먼저 확인하세요.

## Web 개발 시작 시 주의사항

`Web/` 개발을 시작할 때:
1. `coda/coda/coda.config.json`의 `build_cmd`, `test_cmd`, `lint_cmd`가 이미 설정되어 있음
2. TypeScript 사용 예정 — `tsconfig.json` 생성 필요
3. 패키지 매니저는 **pnpm** 사용 (npm/yarn 사용 금지)
