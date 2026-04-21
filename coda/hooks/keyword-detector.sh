#!/usr/bin/env bash
# keyword-detector.sh - UserPromptSubmit hook
# 사용자 프롬프트에서 키워드를 감지하여 관련 프로토콜 리마인더를 주입
#
# Hook event: UserPromptSubmit
# stdin: JSON with "prompt" field
# stdout: JSON with "additionalContext" if keyword matched
# exit 0: always allow (context injection only)

set -u
trap 'exit 0' ERR  # 컨텍스트 주입 전용 — 절대 프롬프트를 차단하지 않음

# Read the user prompt from stdin (safe: reads via stdin, no shell var injection)
INPUT=$(cat || true)
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('prompt', ''))
except:
    print('')
" 2>/dev/null || echo "")

[ -z "$PROMPT" ] && exit 0

CONTEXT=""

# 병렬 작업 키워드
if echo "$PROMPT" | grep -qiE '병렬|parallel|동시'; then
  CONTEXT="${CONTEXT}[병렬작업 프로토콜] Task() 호출 시 독립 작업은 단일 메시지에 여러 tool call로 병렬 실행. 동일 파일 수정은 순차 처리. max_turns 주의.\n"
fi

# 검증 키워드 ("확인" 제거 — 일상 대화 오탐 방지)
if echo "$PROMPT" | grep -qiE '검증|verify|validate|완료'; then
  CONTEXT="${CONTEXT}[검증 프로토콜] 완료 선언 전: 1) 빌드 에러 0개 2) TypeScript 컴파일 통과 3) 관련 테스트 통과 4) 증거 제시 (추정 금지)\n"
fi

# 보안 키워드
if echo "$PROMPT" | grep -qiE '보안|취약점|security|vuln|encrypt|암호화'; then
  CONTEXT="${CONTEXT}[보안 리마인더] 보안 관련 작업은 Security 에이전트(Chloe O'Brian)에 위임 권장. OWASP Top 10 체크. 민감 데이터는 반드시 암호화.\n"
fi

# 커밋 키워드
if echo "$PROMPT" | grep -qiE '커밋|commit|버전|version'; then
  CONTEXT="${CONTEXT}[커밋 프로토콜] /버전업 스킬 호출하여 버전 동기화 확인. 커밋 메시지: <type>: <description> (v버전)\n"
fi

# 버전업 키워드 — VERSION vs CODA_VERSION 혼동 방지 (P1-4)
if echo "$PROMPT" | grep -qiE '버전업|버전 ?올|version.?bump|CODA.?버전'; then
  CONTEXT="${CONTEXT}[버전 파일 구분] 프로젝트 버전: ROOT/VERSION + package.json 3개. CODA 버전: tools/coda/VERSION (별도). 어떤 버전을 올릴지 반드시 확인 후 진행.\n"
fi

# i18n 키워드
if echo "$PROMPT" | grep -qiE 'i18n|번역|translation|다국어|locales|ko\.json|en\.json|ja\.json'; then
  CONTEXT="${CONTEXT}[i18n 동기화] 다국어 파일 키 개수 일치 확인 필수. 키 추가/삭제 시 모든 locale 파일 동시 수정.\n"
fi

# 프로토타입/목업 키워드 — 프로덕션 코드 대신 독립 프로토타입 구현 유도
if echo "$PROMPT" | grep -qiE '목업|프로토타입|mockup|prototype|시안|wireframe'; then
  CONTEXT="${CONTEXT}[프로토타입 모드] 프로덕션 코드를 수정하지 말 것. 독립 HTML 파일로 프로토타입을 생성하여 기존 코드에 영향 없이 시각적으로 확인 가능하게 할 것.\n"
fi

# Output context if any keywords matched
if [ -n "$CONTEXT" ]; then
  HOOK_CONTEXT="$CONTEXT" python3 -c "
import json, os
ctx = os.environ.get('HOOK_CONTEXT', '').strip()
print(json.dumps({'additionalContext': ctx}))
"
fi

exit 0
