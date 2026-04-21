# 프로젝트 메모리

## 빠른 참조
- **프로젝트**: (프로젝트명) (VERSION 파일 참조)
- **빌드**: `pnpm build` | **테스트**: `pnpm test`
- **현재 진행상황**: PROJECT_STATUS.md 하단 "세션 인계용" 섹션 참조
- **아키텍처**: CLAUDE.md 참조

## 반복 실수 방지
- (프로젝트에서 발견된 반복 실수를 여기에 기록)

## 서브에이전트 참고
- Backend 패턴: [backend-patterns.md](backend-patterns.md)
- Frontend 패턴: [frontend-patterns.md](frontend-patterns.md)
- 공통 함정: [common-pitfalls.md](common-pitfalls.md)
- 설계 결정: [architecture-decisions.md](architecture-decisions.md)

## 세션 운영
- 세션 시작 시 SessionStart 훅이 버전+리마인더 자동 주입
- 세션 종료 시 Stop 훅이 상태저장 여부 확인
- 컨텍스트 압축 전 중요 발견은 이 memory/ 파일들에 기록
- memory/ 파일은 주기적으로 정리 (오래된 항목 삭제, MEMORY.md 200줄 이내 유지)
