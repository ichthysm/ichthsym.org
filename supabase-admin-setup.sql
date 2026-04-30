-- ══════════════════════════════════════════════════════
-- ICHTHYS SOLACE 관리자 기능 Supabase 설정 SQL
-- Supabase Dashboard > SQL Editor 에서 실행
-- ══════════════════════════════════════════════════════

-- 1. admin_profiles 테이블 생성
CREATE TABLE IF NOT EXISTS admin_profiles (
  id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name         text NOT NULL,
  email        text,
  role         text NOT NULL DEFAULT 'editor' CHECK (role IN ('super', 'editor')),
  mfa_required boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- 기존 테이블에 email 컬럼 추가 (이미 테이블이 있는 경우)
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS email text;

-- 2. RLS 활성화
ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_posts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE prayer_posts   ENABLE ROW LEVEL SECURITY;

-- 3. admin_profiles RLS 정책
-- 본인 프로필은 본인만 조회
CREATE POLICY "본인 프로필 조회" ON admin_profiles
  FOR SELECT USING (auth.uid() = id);

-- 전체 목록은 슈퍼어드민만 조회
CREATE POLICY "전체 목록 슈퍼어드민 조회" ON admin_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND role = 'super'
    )
  );

-- 슈퍼어드민만 INSERT/UPDATE
CREATE POLICY "슈퍼어드민 프로필 추가" ON admin_profiles
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND role = 'super'
    )
  );

CREATE POLICY "슈퍼어드민 프로필 수정" ON admin_profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM admin_profiles
      WHERE id = auth.uid() AND role = 'super'
    )
  );

-- 4. news_posts RLS 정책
-- 공개 읽기
CREATE POLICY "공개 읽기" ON news_posts
  FOR SELECT USING (true);

-- 관리자만 쓰기
CREATE POLICY "관리자 추가" ON news_posts
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

CREATE POLICY "관리자 수정" ON news_posts
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

CREATE POLICY "관리자 삭제" ON news_posts
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

-- 5. prayer_posts RLS 정책
CREATE POLICY "공개 읽기" ON prayer_posts
  FOR SELECT USING (true);

CREATE POLICY "관리자 추가" ON prayer_posts
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

CREATE POLICY "관리자 수정" ON prayer_posts
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

CREATE POLICY "관리자 삭제" ON prayer_posts
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

-- 6-a. 기존 계정 email 동기화 (email 컬럼 추가 후 1회 실행)
UPDATE admin_profiles ap
SET email = au.email
FROM auth.users au
WHERE ap.id = au.id AND ap.email IS NULL;

-- 6-b. 첫 번째 슈퍼어드민 등록 (Supabase Auth에서 계정 생성 후 UUID 확인)
-- Auth > Users 에서 생성한 계정의 UUID를 아래에 입력
-- INSERT INTO admin_profiles (id, name, email, role, mfa_required)
-- VALUES ('여기에-UUID-입력', '양건호', '이메일@example.com', 'super', false);

-- ══════════════════════════════════════════════════════
-- Supabase Dashboard 설정 (SQL 아님 — 수동 설정)
-- ══════════════════════════════════════════════════════
-- Authentication > Providers > Email
--   - "Confirm email" 비활성화 (신규 관리자 계정 즉시 활성화)
--
-- Authentication > MFA
--   - TOTP 활성화
