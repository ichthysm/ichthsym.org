# ICHTHYS SOLACE — Project Status

**마지막 업데이트**: 2026-04-21
**현재 버전**: v0.1.0
**개발 브랜치**: master

---

## 참조 문서

| 문서 | 설명 |
|------|------|
| [CLAUDE.md](./CLAUDE.md) | 개발 가이드, 아키텍처, 코드 컨벤션 |
| [VERSION](./VERSION) | 현재 버전 (단일 소스) |

---

## 최근 변경사항

### v0.1.0 - 라이브 배포 완료 (2026-04-21)

#### Frontend (유아이)
- `Web/index.html` — HOME 본문 섹션 추가 (사역 카드 3개 + 비전 배너 + 함께하기)
- `Web/style.css` — HOME 신규 섹션 CSS 추가 (`.home-ministry`, `.home-vision-banner`, `.home-join`)
- `Web/style.css` — 게시판 CSS 추가 (`.board-grid`, `.board-card`, `.prayer-list`, `.prayer-item`)
- `Web/tab.js` — 탭 스크립트 공통 파일로 분리 (about/ministry/community 인라인 제거)
- `Web/js/community.js` — Supabase 연동 게시판 (선교지 소식, 정기 기도 모임)
- 4개 페이지 META 태그 + favicon 적용
- 로그인/회원가입 링크 주석 처리
- 탭 패널 Lorem Ipsum + picsum.photos 더미 이미지 적용

#### Backend / 인프라 (박안도)
- Supabase 프로젝트 연결 (`hsozcqbisfcswfvjepqv.supabase.co`)
- `news_posts` 테이블 생성 (id, title, content, image_url, created_at)
- `prayer_posts` 테이블 생성 (id, title, content, created_at)
- RLS 공개 읽기 정책 적용

#### DevOps (배포준)
- GitHub 레포 연결: `ichthysm/ichthsym.org`
- Vercel 배포 완료: `https://ichthsym-org.vercel.app`
- GitHub push → Vercel 자동 배포 파이프라인 구성
- Vercel MCP 플러그인 설치 완료

#### 미완료 / 알려진 이슈
- 히어로 배경 이미지: ABOUT/MINISTRY/COMMUNITY 임시 이미지 사용 중 (실제 사진 필요)
- 후원 계좌번호 실제 정보 미입력 (현재 000-0000-0000-00)
- 도메인 연결 미완료 (나중에 진행 예정)
- 반응형(모바일) 미구현 (PC 전용)

---

## 현재 진행 상황 (세션 인계용)

### 마지막 작업
- 수행한 작업: HOME 본문 완성 + Supabase 게시판 연동 + GitHub push + Vercel 배포
- 수정한 파일: `Web/index.html`, `Web/style.css`, `Web/tab.js`, `Web/js/community.js`, `Web/about.html`, `Web/ministry.html`, `Web/community.html`
- 커밋 여부: 완료 (master 브랜치)

### 진행 중 작업 (미완료)
- [ ] 히어로 배경 이미지 교체 — ABOUT/MINISTRY/COMMUNITY 실제 사진 필요 (캡틴 제공)
- [ ] 후원 계좌 실제 정보 입력
- [ ] 도메인 연결 (캡틴 결정 후)

### 다음 세션 TODO
1. 도메인 연결 (Vercel → 커스텀 도메인)
2. 히어로 이미지 교체 (실제 사진 확보 후)
3. 후원 계좌번호 실제 정보 입력
4. Supabase 게시판 글 실제 콘텐츠로 채우기
