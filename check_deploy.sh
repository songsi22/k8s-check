#!/bin/bash
echo "-----------------------------------------"
echo "Checking Deployment Status..."
echo "-----------------------------------------"

found_issue=0

# 📝 Deployments 정보를 임시 파일에 저장하여 서브쉘 문제 방지
temp_file=$(mktemp)
kubectl get deploy -A --no-headers | grep -v velero > "$temp_file"

while read -r namespace deploy ready_status rest; do
    ready_count=$(echo "$ready_status" | cut -d'/' -f1)
    total_count=$(echo "$ready_status" | cut -d'/' -f2)

    if [ "$ready_count" -ne "$total_count" ]; then
        echo "Issue detected: $namespace / $deploy ($ready_status)"
        found_issue=1

        # 📝 해당 Deployment의 Pods 정보를 임시 파일에 저장
        pod_temp_file=$(mktemp)
        kubectl get pods -n "$namespace" --no-headers | grep "$deploy" | awk '{print $1}' > "$pod_temp_file"

        # 🔍 Pod 이벤트 확인
        while read -r pod; do
            echo "Events for Pod: $pod in Namespace: $namespace"
            kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod" --sort-by=.lastTimestamp
            echo "-----------------------------------------"
        done < "$pod_temp_file"
        
        rm -f "$pod_temp_file"  # Pod 리스트 임시 파일 삭제
    fi
done < "$temp_file"

rm -f "$temp_file"  # Deployment 리스트 임시 파일 삭제

# ✅ 최종 결과 출력
if [ "$found_issue" -eq 0 ]; then
    echo "All Deployments are healthy!"
fi
