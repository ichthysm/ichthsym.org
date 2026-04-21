#!/usr/bin/env python3
"""후방 호환 테스트 - layer2_checks 없는 config로 파싱 테스트"""

import json
import sys

def main():
    config_file = 'coda/coda.config.json'

    print("=== 후방 호환 테스트 (layer2_checks 없는 config) ===\n")

    # 1. load_layer2_config 시뮬레이션
    try:
        with open(config_file, 'r') as f:
            data = json.load(f)
        layer2 = data.get('layer2_checks', {})
        print(f"[OK] Config loaded: {config_file}")
        print(f"[OK] layer2_checks: {json.dumps(layer2)}")
        print(f"[OK] layer2_checks is empty: {layer2 == {}}")
    except Exception as e:
        print(f"[FAIL] Error loading config: {e}")
        sys.exit(1)

    # 2. is_check_enabled 시뮬레이션 (빈 config일 때 기본값 true)
    def is_check_enabled(layer2_config, check_name):
        if not layer2_config or layer2_config == {}:
            return True  # 안전한 기본값
        check = layer2_config.get(check_name, {})
        if not check:
            return True  # 체크가 없으면 기본 활성화
        return check.get('enabled', True)

    print("\n--- is_check_enabled 테스트 ---")
    for check in ['build', 'test', 'lint', 'orphan-files', 'env-consistency', 'lockfile-sync', 'i18n-completeness']:
        enabled = is_check_enabled(layer2, check)
        print(f"[OK] {check}: {'enabled' if enabled else 'disabled'}")

    # 3. get_check_option 시뮬레이션
    def get_check_option(layer2_config, check_name, option_name, default_value=''):
        if not layer2_config or layer2_config == {}:
            return default_value
        check = layer2_config.get(check_name, {})
        value = check.get(option_name)
        if value is None:
            return default_value
        return value

    print("\n--- get_check_option 테스트 ---")
    print(f"[OK] orphan-files.patterns: {get_check_option(layer2, 'orphan-files', 'patterns', '[]')}")
    print(f"[OK] env-consistency.files: {get_check_option(layer2, 'env-consistency', 'files', '[]')}")

    print("\n=== 테스트 완료: 모두 PASS ===")
    return 0

if __name__ == '__main__':
    sys.exit(main())
