#!/bin/bash

# 색상 정의
RED='\033[31m'    # 빨간색 (CPU & Mem 초과)
ORANGE='\033[33m' # 주황색 (CPU 초과)
PINK='\033[35m'   # 핑크색 (Memory 초과)
GREEN='\033[32m'  # 초록색 (정상)
NC='\033[0m'      # 색상 초기화

echo "-----------------------------------------"
echo "Checking Pod Resource Usage..."
echo "-----------------------------------------"

kubectl top pod -A --no-headers | while read namespace pod cpu_usage mem_usage; do
    cpu_usage=$(echo "$cpu_usage" | sed 's/m//')

    # Memory 사용량 변환 (Gi → Mi, Ki → Mi, Byte → Mi 변환 추가)
    case "$mem_usage" in
        *Gi)
            mem_usage=$(echo "$mem_usage" | sed 's/Gi//' | awk '{printf "%.0f", $1 * 1024}')
            ;;
        *Mi)
            mem_usage=$(echo "$mem_usage" | sed 's/Mi//')
            ;;
        *k)
            mem_usage=$(echo "$mem_usage" | sed 's/k//' | awk '{printf "%.0f", $1 / 1024}')
            ;;
        *[0-9])  # 단위가 없는 경우 (바이트 단위)
            mem_usage=$(awk "BEGIN {printf \"%.0f\", $mem_usage / 1048576}")
            ;;
        *)
            echo "Invalid memory unit: $mem_usage"
            continue
            ;;
    esac

    # Limits 확인
    limits=$(kubectl describe pod "$pod" -n "$namespace" | grep -A5 "Limits")

    # CPU Limits 가져오기 (단위 없는 경우 1000을 곱함)
    cpu_limit=$(echo "$limits" | grep "cpu:" | awk '{print $2}' | head -n1)

    case "$cpu_limit" in
        *m)  # milliCPU (예: 500m)
            cpu_limit=$(echo "$cpu_limit" | sed 's/m//')
            ;;
        *[0-9])  # 단위 없는 경우 (Core 단위 → milliCPU 변환 필요)
            cpu_limit=$(awk "BEGIN {printf \"%.0f\", $cpu_limit * 1000}")
            ;;
        *)
            echo "No Limits: $pod"
            continue
            ;;
    esac

    if [ -z "$cpu_limit" ]; then cpu_limit=1000; fi  # 기본값 설정

    # Memory Limits 가져오기 (Gi → Mi, Ki → Mi, Byte → Mi 변환 추가)
    mem_limit=$(echo "$limits" | grep "memory:" | awk '{print $2}' | head -n1)
    case "$mem_limit" in
        *Gi)
            mem_limit=$(echo "$mem_limit" | sed 's/Gi//' | awk '{printf "%.0f", $1 * 1024}')
            ;;
        *Mi)
            mem_limit=$(echo "$mem_limit" | sed 's/Mi//')
            ;;
        *k)
            mem_limit=$(echo "$mem_limit" | sed 's/k//' | awk '{printf "%.0f", $1 / 1024}')
            ;;
        *[0-9])  # 단위가 없는 경우 (바이트 단위)
            mem_limit=$(awk "BEGIN {printf \"%.0f\", $mem_limit / 1048576}")
            ;;
        *)
            echo "No Limits: $pod"
            continue
            ;;
    esac

    if [ -z "$mem_limit" ]; then mem_limit=2000; fi  # 기본값 설정

    # 임계치 계산 (Limits 기준)
    cpu_threshold=$((cpu_limit * 70 / 100))
    mem_threshold=$((mem_limit * 90 / 100))

    # CPU, Memory 임계치 초과 여부 체크
    cpu_exceeded=false
    mem_exceeded=false

    if [ "$cpu_usage" -ge "$cpu_threshold" ]; then
        cpu_exceeded=true
    fi

    if [ "$mem_usage" -ge "$mem_threshold" ]; then
        mem_exceeded=true
    fi

    # 색상별 출력
    if [ "$cpu_exceeded" = true ] && [ "$mem_exceeded" = true ]; then
        # CPU & Mem 초과 (빨간색)
        echo "${RED}WARNING: $pod (CPU: ${cpu_usage}m / ${cpu_limit}m, Memory: ${mem_usage}Mi / ${mem_limit}Mi)${NC}"
    elif [ "$cpu_exceeded" = true ]; then
        # CPU 초과 (주황색)
        echo "${ORANGE}CPU High: $pod (CPU: ${cpu_usage}m / ${cpu_limit}m, Memory: ${mem_usage}Mi / ${mem_limit}Mi)${NC}"
    elif [ "$mem_exceeded" = true ]; then
        # Memory 초과 (핑크색)
        echo "${PINK}MEM High: $pod (CPU: ${cpu_usage}m / ${cpu_limit}m, Memory: ${mem_usage}Mi / ${mem_limit}Mi)${NC}"
    else
        # 정상 (초록색)
        echo "${GREEN}OK: $pod (CPU: ${cpu_usage}m / ${cpu_limit}m, Memory: ${mem_usage}Mi / ${mem_limit}Mi)${NC}"
    fi
done
