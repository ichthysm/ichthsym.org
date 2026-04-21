# ICHTHYS SOLACE — Project Status

**마지막 업데이트**: 2026-04-21
**현재 버전**: v0.1.0
**개발 브랜치**: main

---

## 참조 문서

| 문서 | 설명 |
|------|------|
| [CLAUDE.md](./CLAUDE.md) | 개발 가이드, 아키텍처, 코드 컨벤션 |
| [VERSION](./VERSION) | 현재 버전 (단일 소스) |

---

## 최근 변경사항

### v0.1.0 - Web 정적 사이트 초기 구축 완료 (2026-04-21)

#### Frontend (유아이)
- `Web/style.css` 생성 — 공통 CSS (헤더/히어로/탭바/콘텐츠/푸터)
- `Web/index.html` — HOME 페이지 (main.png 풀이미지 히어로)
- `Web/about.html` — ABOUT 페이지 (환영의 글/소개/비전 탭)
- `Web/ministry.html` — MINISTRY 페이지 (선교사 회복/북한 고아/외국인 사역 탭)
- `Web/community.html` — COMMUNITY 페이지 (선교지 소식/온라인 기도/후원 안내 탭)
- `Web/img/` — Mobile/img 복사 + main.png 신규 추가
- 네비게이션: 올리브 그린 상단바 + 흰 배경 메인 nav (로고 좌, 링크 우)
- 히어로 구조: 72vh 이미지(HOME은 풀이미지) + 탭바 absolute bottom + 하단 콘텐츠 패널

#### 디자인 시스템
- 올리브 주조색: `#6b7c4a`
- 배지 그린: `#6b7c4a`
- 상단바 배경: `#6b7c4a`
- 타이포: Playfair Display (제목), Noto Serif KR / Noto Sans KR (본문)
- 레이아웃 컨테이너: `width: 90vw; max-width: 1200px; margin: 0 auto`
- 반응형 타이포: `clamp()` 전체 적용

#### 미완료 / 알려진 이슈
- Mobile/index.html 별도 개선 중단 (Web 우선 전환)
- 히어로 배경 이미지: 샘플 원본 이미지와 다름 (임시 대체 이미지 사용 중)
- 로그인/회원가입 기능 미구현 (링크 `#` 처리)
- 후원 계좌 등 실제 정보 미입력

---

## 현재 진행 상황 (세션 인계용)

### 마지막 작업
- 수행한 작업: Web 4개 페이지 분리 + style.css 공통화 + HOME 히어로 main.png 교체 + 네비 디자인 변경(올리브 상단바 + 흰 nav)
- 수정한 파일: `Web/style.css`, `Web/index.html`, `Web/about.html`, `Web/ministry.html`, `Web/community.html`
- 커밋 여부: 미완료

### 진행 중 작업 (미완료)
- [ ] 로고 크기/위치 최종 확정 (현재 80px)
- [ ] HOME 히어로 이미지 잘림 이슈 해결 (`<img>` 태그로 전환, margin-top 120px 적용)
- [ ] ABOUT/MINISTRY/COMMUNITY 히어로 배경 이미지 교체 (고품질 원본 필요)

### 다음 세션 TODO
1. 히어로 섹션 이미지 교체 — 샘플과 동일한 분위기 이미지 확보
2. 탭 콘텐츠 실제 텍스트/이미지 채우기 (현재 플레이스홀더)
3. 반응형 점검 (1200px 이하 브라우저)
4. Mobile/index.html 박스 스타일 마무리
