#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <v1|v2|v3-broken>"
  exit 2
fi

TARGET="$1"
echo "Rolling to $TARGET"

case "$TARGET" in
  v1)
    kubectl set env deployment/demo-service APP_VERSION=v1 READY_DELAY_SECONDS=0 NEVER_READY=false
    ;;
  v2)
    kubectl set env deployment/demo-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
    ;;
  v3-broken)
    kubectl set env deployment/demo-service APP_VERSION=v3-broken READY_DELAY_SECONDS=0 NEVER_READY=true
    ;;
  *)
    echo "Unknown target: $TARGET"
    exit 2
    ;;
esac

echo "Waiting for rollout (timeout 180s)..."
if kubectl rollout status deployment/demo-service --timeout=180s; then
  echo "Rollout to $TARGET succeeded"
  exit 0
else
  echo "Rollout to $TARGET failed or timed out"
  kubectl get pods -l app=demo-service -o wide
  kubectl describe deployment demo-service || true
  kubectl get events --sort-by=.metadata.creationTimestamp | tail -n 50 || true
  exit 1
fi
