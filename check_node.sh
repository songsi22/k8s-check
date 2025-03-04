#!/bin/bash

# ANSI 색상 코드
RED='\033[31m'   # 빨간색 (경고)
GREEN='\033[32m' # 초록색 (정상)
NC='\033[0m'     # 색상 초기화

echo "-----------------------------------------"
echo "Checking Node Status"
echo "-----------------------------------------"

found_issue=0

temp_file=$(mktemp)
kubectl get nodes -o wide --no-headers > "$temp_file"

while read -r node_name status rest; do
    if [ "$status" != "Ready" ]; then
        echo -e "${RED}$node_name - $status${NC}"
        found_issue=1
    fi
done < "$temp_file"
rm -f "$temp_file"  

if [ "$found_issue" -eq 0 ]; then
    echo "${GREEN}All nodes are Ready!${NC}"
fi

echo "-----------------------------------------"
echo "List of pod counts by node"
echo "-----------------------------------------"
kubectl get pods -A -o custom-columns="NAMESPACE:.metadata.namespace,POD:.metadata.name,NODE:.spec.nodeName" --no-headers | awk '{print $3}' | sort | uniq -c | awk '{print $2, $1}' | column -t

