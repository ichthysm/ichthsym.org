# ICHTHYS SOLACE — Project Status

**마지막 업데이트**: 2026-04-30
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

### v0.1.0 - 관리자 페이지 구현 및 버그 분석 (2026-04-30)

#### Frontend (유아이)
- `Web/admin.html` — 관리자 페이지 신규 (로그인 3단계 + 대시보드 레이아웃)
- `Web/js/admin.js` — 인증(이메일+패스워드+TOTP) + CRUD + 관리자 관리 + 비밀번호 변경
- `Web/admin.html` — 사이드바 "내 계정" 버튼 + 비밀번호 변경 모달 추가
- `Web/admin.html` — 사이드바 이모지 제거
- `Web/admin.html` — 용어 정리: "관리자 추가" → "사용자 추가", 역할 관리자/편집자
- `Web/admin.html` — 사용자 추가 폼 `autocomplete="off"` (브라우저 자동완성 차단)
- `Web/community.html` — 히어로 배지 ICHTHYS CONTACT → ICHTHYS COMMUNITY

#### Backend (박안도)
- `supabase-admin-setup.sql` — admin_profiles 테이블 + RLS 정책 SQL (프로젝트 루트)
- Supabase RLS 정책 수정: SELECT 순환참조 제거 → `인증된 관리자 조회` 정책으로 교체
- `Web/js/admin.js` — signUp 후 슈퍼어드민 세션 복원 버그 수정 (setSession)
- `Web/js/admin.js` — TOTP QR 렌더링 버그 수정 (innerHTML → createElement)

#### 버그 분석 완료 (미수정)
- **OTP 뒤로가기 우회**: `signInWithPassword` 후 localStorage에 세션 저장 → `init()`이 TOTP 미완료 상태에서 대시보드 진입 허용. 수정: `init()`에서 AAL(aal2) 검증 추가 필요
- **로그아웃 캐시 잔존**: `signOut()` 비동기 미완료 상태에서 `location.reload()` 실행. 수정: `location.href` 재지정 + `localStorage` 전체 초기화 필요

---

### v0.1.0 - 콘텐츠 업데이트 (2026-04-29)

#### Frontend (유아이)
- `Web/img/17_logo_banner.png` — 상단 배너 로고 이미지 추가
- nav 로고 `17_logo_banner.png`로 교체 (4개 페이지)
- `Web/index.html` — 사역 카드 링크 탭 해시 추가 (`#recovery`, `#orphan`, `#foreigner`)
- `Web/ministry.html` — 선교사 회복 신청 연락처 카드 추가, 건강검진 지원 항목 추가
- `Web/about.html` — 환영의 글 서명 수정, 이미지 교체
- `Web/style.css` — 네비 로고 원형 배경, 연락처 카드 CSS

---

### v0.1.0 - 라이브 배포 완료 (2026-04-21)

#### Frontend (유아이)
- `Web/index.html` — HOME 본문 (사역 카드 3개 + 비전 배너 + 함께하기)
- `Web/js/community.js` — Supabase 연동 게시판
- 4개 페이지 META 태그 + favicon

#### Backend / 인프라 (박안도)
- Supabase: `news_posts`, `prayer_posts` 테이블, RLS 공개 읽기

#### DevOps (배포준)
- GitHub 레포: `ichthysm/ichthsym.org`
- Vercel 자동 배포, 도메인 `www.ichthysm.org` 연결 완료

---

## 현재 진행 상황 (세션 인계용)

### 마지막 작업
- 수행한 작업: 관리자 페이지 구현 완료 + 버그 2건 원인 분석
- 수정한 파일: `Web/admin.html`, `Web/js/admin.js`, `supabase-admin-setup.sql`
- 커밋 여부: 완료 (master 브랜치)

### 진행 중 작업 (미완료)
- [ ] **OTP 뒤로가기 우회 버그 수정** — `init()`에서 AAL aal2 검증 추가
- [ ] **로그아웃 캐시 잔존 버그 수정** — `location.href` 재지정 + localStorage 초기화
- [ ] `Docs/익투스-고유번호증.jpeg` git 추적 해제 (`git rm --cached`)

### 다음 세션 TODO
1. **[P0]** admin.js 버그 2건 수정 (OTP 우회 + 로그아웃 캐시)
2. **[P1]** Supabase Storage 이미지 업로드 기능 (공개 버킷, news_posts)
3. **[P2]** 이용약관 페이지 추가 (footer 링크)
4. **[P3]** `Docs/익투스-고유번호증.jpeg` 추적 해제
