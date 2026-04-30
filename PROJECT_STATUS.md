# ICHTHYS SOLACE — Project Status

**마지막 업데이트**: 2026-04-30 (세션 2)
**현재 버전**: v0.1.0
**개발 브랜치**: master

---

## 참조 문서

| 문서 | 설명 |
|------|------|
| [CLAUDE.md](./CLAUDE.md) | 개발 가이드, 아키텍처, 코드 컨벤션 |
| [CHANGELOG.md](./CHANGELOG.md) | 전체 변경 이력 (아카이브) |
| [VERSION](./VERSION) | 현재 버전 (단일 소스) |

---

## 최근 변경사항

### v0.1.0 - 팝업 관리 기능 추가 (2026-04-30)

#### Frontend (유아이)
- `Web/admin.html` — 사이드바 "팝업 관리" 탭 추가
- `Web/admin.html` — 팝업 패널 (목록: 제목/유형/상태/기간/관리)
- `Web/admin.html` — 팝업 작성/수정 모달 (템플릿 3종 + 예약게시 + 활성화 토글)
- `Web/js/popup.js` — 프론트 팝업 렌더러 신규 (최대 2개 동시, 오늘 하루 안보기, localStorage)
- `Web/index.html` — popup.js 모듈 로드 추가

#### Backend (박안도)
- `Web/js/admin.js` — 팝업 CRUD 함수 추가 (`loadPopups`, `openPopupModal`, `getPopupStatus`, `formatDateRange`, `toDatetimeLocal`)
- `Web/js/admin.js` — link_url 검증 (https:// 또는 / 시작 강제)
- `Web/js/admin.js` — starts_at/ends_at 유효성 검사 (종료 > 시작)
- `supabase-popup-setup.sql` — `popups` 테이블 + RLS 2개 정책 신규

---

### v0.1.0 - admin.js P0 버그 수정 (2026-04-30)

#### Backend (박안도)
- `Web/js/admin.js` — `init()` AAL aal2 검증 추가: MFA 필수 계정이 세션 복원 시 TOTP 미완료면 TOTP 화면으로 강제 이동 (OTP 뒤로가기 우회 방지)
- `Web/js/admin.js` — logout: `localStorage.clear()` + `sessionStorage.clear()` + `location.href` 리디렉션 (로그아웃 캐시 잔존 방지)
- `Web/js/admin.js` — `loadAdmins()`: UUID 대신 `admin.email` 표시
- `Web/js/admin.js` — `modal-admin-save`: `admin_profiles` INSERT에 `email` 포함
- `supabase-admin-setup.sql` — `email` 컬럼 추가 (`ADD COLUMN IF NOT EXISTS`) + 기존 계정 email 동기화 쿼리 (`UPDATE ... FROM auth.users`) + INSERT 예시 업데이트

---

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
- 수행한 작업: 팝업 관리 기능 전체 구현 (관리자 CRUD + 프론트 렌더러)
- 신규 파일: `Web/js/popup.js`, `supabase-popup-setup.sql`
- 수정 파일: `Web/admin.html`, `Web/js/admin.js`, `Web/index.html`
- 커밋 여부: 완료 (master 브랜치, bac9ec2)

### 진행 중 작업 (미완료)
- [ ] **Supabase SQL 실행 필요** — `supabase-popup-setup.sql` (popups 테이블 생성)
- [ ] **Supabase SQL 실행 필요** — 기존 계정 email 컬럼 동기화
  ```sql
  ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS email text;
  UPDATE admin_profiles ap SET email = au.email FROM auth.users au WHERE ap.id = au.id AND ap.email IS NULL;
  ```

### 다음 세션 TODO
1. **[P0]** Supabase SQL 2건 실행 확인 (popup 테이블 + email 동기화)
2. **[P1]** Supabase Storage 이미지 업로드 기능 (공개 버킷, news_posts + popups)
3. **[P2]** 이용약관 페이지 추가 (footer 링크)
4. **[P3]** `Docs/익투스-고유번호증.jpeg` 추적 해제 (`git rm --cached`)
