#!/bin/bash
echo "-----------------------------------------"
echo "Checking DaemonSet Status..."
echo "-----------------------------------------"

found_issue=0
header_printed=false

# 📝 DaemonSet 정보를 임시 파일에 저장 (서브쉘 문제 방지)
temp_file=$(mktemp)
kubectl get ds -A --no-headers > "$temp_file"

while read -r namespace ds_name desired current ready up_to_date available rest; do
    # 값이 숫자인지 확인 후 비교 수행
    if echo "$desired" | grep -qE '^[0-9]+$' && echo "$current" | grep -qE '^[0-9]+$' && echo "$available" | grep -qE '^[0-9]+$'; then
        if [ "$desired" -ne "$current" ] || [ "$desired" -ne "$available" ]; then
            # 헤더가 아직 출력되지 않았다면 출력
            if [ "$header_printed" = false ]; then
                echo "NAMESPACE      DAEMONSET                         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE"
                header_printed=true
            fi
            echo "$namespace  $ds_name  $desired  $current  $ready  $up_to_date  $available"
            found_issue=1

            # 해당 DaemonSet의 이벤트 가져오기
            echo "Events for DaemonSet: $ds_name in Namespace: $namespace"
            kubectl get events -n "$namespace" --field-selector involvedObject.kind=DaemonSet,involvedObject.name="$ds_name" --sort-by=.lastTimestamp
            echo "-----------------------------------------"
        fi
    fi
done < "$temp_file"

rm -f "$temp_file"  # 임시 파일 삭제

# 모든 DaemonSet이 정상인 경우
if [ "$found_issue" -eq 0 ]; then
    echo "All DaemonSets are healthy!"
fi
