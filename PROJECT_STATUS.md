# ICHTHYS SOLACE — Project Status

**마지막 업데이트**: 2026-04-29
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

### v0.1.0 - 콘텐츠 업데이트 및 관리자 기능 설계 (2026-04-29)

#### Frontend (유아이)
- `Web/img/17_logo_banner.png` — 상단 배너 로고 이미지 추가 (번호 규칙 적용)
- `Web/index.html`, `about.html`, `ministry.html`, `community.html` — nav 로고 `17_logo_banner.png`로 교체
- `Web/style.css` — 네비 로고 원형 배경 복원 (76px circle, `#f5f5f0`)
- `Web/index.html` — 사역 카드 링크 탭 해시 추가 (`#recovery`, `#orphan`, `#foreigner`)
- `Web/ministry.html` — 선교사 회복 프로그램 신청 연락처 카드 추가 (담당: 정 사마리아 선교사, 010-4533-9642, yejihaha@gmail.com)
- `Web/ministry.html` — 회복 프로그램 항목 `건강검진 지원` 추가
- `Web/about.html` — 환영의 글 서명 문구 수정 → "익투스 솔리스 미션 일동"
- `Web/img/02_welcome.jpg` — 환영의 글 이미지 교체 (KakaoTalk 실제 사진)
- `Web/style.css` — `.contact-card` 신청 안내 카드 CSS 추가

#### 설계 완료 (미구현)
- 관리자 페이지 설계 확정:
  - Supabase Auth 이메일+패스워드 로그인
  - TOTP MFA (Google Authenticator, 사용자별 활성/비활성 옵션)
  - `admin_profiles` 테이블 (id, name, role: super|editor, mfa_required)
  - 슈퍼어드민이 앱 내에서 관리자 계정 생성/관리
  - `news_posts`, `prayer_posts` CRUD
  - RLS: `admin_profiles` 등록 사용자만 쓰기 허용

#### 기타
- `Docs/익투스-고유번호증.jpeg` — git 추적 중이나 미커밋 (민감 문서, 추적 해제 검토 필요)

---

### v0.1.0 - 라이브 배포 완료 (2026-04-21)

#### Frontend (유아이)
- `Web/index.html` — HOME 본문 섹션 추가 (사역 카드 3개 + 비전 배너 + 함께하기)
- `Web/style.css` — HOME 신규 섹션 CSS 추가 (`.home-ministry`, `.home-vision-banner`, `.home-join`)
- `Web/style.css` — 게시판 CSS 추가 (`.board-grid`, `.board-card`, `.prayer-list`, `.prayer-item`)
- `Web/tab.js` — 탭 스크립트 공통 파일로 분리
- `Web/js/community.js` — Supabase 연동 게시판 (선교지 소식, 정기 기도 모임)
- 4개 페이지 META 태그 + favicon 적용

#### Backend / 인프라 (박안도)
- Supabase 프로젝트 연결 (`hsozcqbisfcswfvjepqv.supabase.co`)
- `news_posts` 테이블 생성 (id, title, content, image_url, created_at)
- `prayer_posts` 테이블 생성 (id, title, content, created_at)
- RLS 공개 읽기 정책 적용

#### DevOps (배포준)
- GitHub 레포: `ichthysm/ichthsym.org`
- Vercel 자동 배포, 도메인 `www.ichthysm.org` 연결 완료

---

## 현재 진행 상황 (세션 인계용)

### 마지막 작업
- 수행한 작업: 콘텐츠 업데이트(로고/이미지/문구), 연락처 카드, 관리자 기능 설계
- 수정한 파일: `Web/ministry.html`, `Web/about.html`, `Web/index.html`, `Web/style.css`, `Web/img/`
- 커밋 여부: 완료 (master 브랜치)

### 진행 중 작업 (미완료)
- [ ] 관리자 페이지 개발 (`admin.html` + `js/admin.js`)
- [ ] `Docs/익투스-고유번호증.jpeg` git 추적 해제

### 다음 세션 TODO
1. **[P0] 관리자 페이지 개발** — Supabase Auth + TOTP MFA + CRUD + 다중 관리자
   - Supabase 설정: MFA 활성화, 이메일 인증 비활성화, admin_profiles 테이블 생성 (캡틴 직접)
   - `admin.html` + `js/admin.js` 구현
2. **[P1]** `Docs/익투스-고유번호증.jpeg` 추적 해제 (`git rm --cached`)
3. **[P2]** 히어로 이미지 교체 (실제 사진 확보 후)
