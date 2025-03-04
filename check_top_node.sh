#!/bin/bash

# ANSI 색상 코드
RED='\033[31m'   # 빨간색 (경고)
GREEN='\033[32m' # 초록색 (정상)
NC='\033[0m'     # 색상 초기화

echo "-----------------------------------------"
echo "Checking Node Resource Usage..."
echo "-----------------------------------------"

# kubectl top node 실행 및 처리
kubectl top node --no-headers | while read node_name cpu_usage mem_usage rest; do
    # CPU와 메모리 값에서 단위 제거
    cpu_value=$(echo "$cpu_usage" | sed 's/m//')   # "3250m" → "3250"
    mem_value=$(echo "$mem_usage" | sed 's/%//')   # "85%" → "85"

    # CPU 또는 메모리 사용률이 기준 초과시 경고
    if [ "$cpu_value" -ge 7000 ] || [ "$mem_value" -ge 90 ]; then
        echo "${RED}WARNING: $node_name - CPU: $cpu_usage, Memory: $mem_usage${NC}"
    else
        echo "${GREEN}OK: $node_name - CPU: $cpu_usage, Memory: $mem_usage${NC}"
    fi
done
