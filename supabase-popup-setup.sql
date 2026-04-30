-- ICHTHYS SOLACE — 팝업 관리 테이블
-- Supabase SQL Editor에서 실행

CREATE TABLE IF NOT EXISTS popups (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type        text NOT NULL DEFAULT 'text' CHECK (type IN ('image', 'text', 'notice')),
  title       text NOT NULL,
  content     text,
  image_url   text,
  link_url    text,
  starts_at   timestamptz,
  ends_at     timestamptz,
  is_active   boolean NOT NULL DEFAULT true,
  created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE popups ENABLE ROW LEVEL SECURITY;

-- 공개 읽기 (프론트엔드에서 활성 팝업 조회)
CREATE POLICY "팝업 공개 조회" ON popups
  FOR SELECT USING (true);

-- 인증된 관리자만 생성/수정/삭제
CREATE POLICY "관리자 팝업 관리" ON popups
  FOR ALL USING (
    EXISTS (SELECT 1 FROM admin_profiles WHERE id = auth.uid())
  );

-- 예시 데이터 (선택, 실행 후 admin에서 삭제 가능)
-- INSERT INTO popups (type, title, content, is_active)
-- VALUES ('notice', '사이트 오픈 안내', 'ICHTHYS SOLACE 홈페이지가 공식 오픈되었습니다. 기도로 함께해 주세요.', true);
