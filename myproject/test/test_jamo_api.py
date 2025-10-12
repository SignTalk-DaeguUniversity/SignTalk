#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
자모 분해 API 테스트 스크립트
"""

import requests
import json

BASE_URL = "http://localhost:5002"

def test_decompose_post():
    """POST 방식 자모 분해 테스트"""
    print("\n=== POST /api/jamo/decompose 테스트 ===")
    
    test_cases = [
        "안녕",
        "안녕하세요",
        "ㄱㄴㄷ",
        "한글",
        "감사합니다"
    ]
    
    for text in test_cases:
        response = requests.post(
            f"{BASE_URL}/api/jamo/decompose",
            json={"text": text, "include_complex": False}
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n'{text}' 분해 결과:")
            print(f"  자모 리스트: {data['jamo_list']}")
            print(f"  자모 개수: {data['jamo_count']}")
            print(f"  글자 개수: {data['char_count']}")
        else:
            print(f"❌ 오류: {response.status_code}")


def test_decompose_get():
    """GET 방식 자모 분해 테스트"""
    print("\n=== GET /api/jamo/decompose/<text> 테스트 ===")
    
    text = "안녕"
    response = requests.get(f"{BASE_URL}/api/jamo/decompose/{text}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"\n'{text}' 분해 결과:")
        print(f"  자모 리스트: {data['jamo_list']}")
    else:
        print(f"❌ 오류: {response.status_code}")


def test_validate():
    """자모 검증 테스트"""
    print("\n=== POST /api/jamo/validate 테스트 ===")
    
    test_jamos = ['ㄱ', 'ㅏ', 'ㄴ', 'ㄲ', 'ㅘ', 'A']
    
    for jamo in test_jamos:
        response = requests.post(
            f"{BASE_URL}/api/jamo/validate",
            json={"jamo": jamo}
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n'{jamo}' 검증 결과:")
            print(f"  유효: {data['is_valid']}")
            print(f"  타입: {data.get('type', 'N/A')}")
            print(f"  복합 자모: {data.get('is_complex', False)}")
        else:
            print(f"❌ 오류: {response.status_code}")


def test_info():
    """자모 정보 테스트"""
    print("\n=== GET /api/jamo/info 테스트 ===")
    
    response = requests.get(f"{BASE_URL}/api/jamo/info")
    
    if response.status_code == 200:
        data = response.json()
        print(f"\n자모 시스템 정보:")
        print(f"  초성 개수: {data['chosung_count']}")
        print(f"  중성 개수: {data['jungsung_count']}")
        print(f"  종성 개수: {data['jongsung_count']}")
        print(f"  전체 자모: {data['total_jamo_count']}")
        print(f"  초성 목록: {data['chosung_list']}")
    else:
        print(f"❌ 오류: {response.status_code}")


if __name__ == "__main__":
    print("🚀 자모 분해 API 테스트 시작")
    print(f"서버: {BASE_URL}")
    
    try:
        test_decompose_post()
        test_decompose_get()
        test_validate()
        test_info()
        
        print("\n✅ 모든 테스트 완료!")
        
    except requests.exceptions.ConnectionError:
        print("\n❌ 서버에 연결할 수 없습니다.")
        print("Flask 서버가 실행 중인지 확인하세요: python app.py")
    except Exception as e:
        print(f"\n❌ 테스트 실패: {e}")
