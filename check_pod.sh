#!/bin/bash
echo "-----------------------------------------"
echo "Checking Pod Status..."
echo "-----------------------------------------"

found_issue=0

# Pod 정보를 임시 파일에 저장하여 서브쉘 문제 방지
temp_file=$(mktemp)
kubectl get pods -A --no-headers | grep -v velero > "$temp_file"

while read -r namespace pod ready status rest; do
    # "/" 기준으로 Ready 개수와 총 개수 나누기
    ready_count=$(echo "$ready" | cut -d'/' -f1)
    total_count=$(echo "$ready" | cut -d'/' -f2)

    # Pod 상태가 Running이 아니거나 Ready가 비정상적인 경우
    if [ "$status" != "Running" ] || [ "$ready_count" -ne "$total_count" ]; then
        echo "Issue detected: $namespace / $pod (Ready: $ready, Status: $status)"
        found_issue=1

        # 해당 Pod의 이벤트 가져오기
        echo "Events for Pod: $pod in Namespace: $namespace"
        kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod" --sort-by=.lastTimestamp
        echo "-----------------------------------------"
    fi
done < "$temp_file"

rm -f "$temp_file"  # 임시 파일 삭제

# 모든 Pod가 정상인 경우
if [ "$found_issue" -eq 0 ]; then
    echo "All Pods are healthy!"
fi
