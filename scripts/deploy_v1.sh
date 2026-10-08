#!/usr/bin/env bash
set -euo pipefail

echo "Applying Service and Deployment (v1 ready immediately)..."
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml

kubectl set env deployment/demo-service APP_VERSION=v1 READY_DELAY_SECONDS=0 NEVER_READY=false

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/demo-service --timeout=120s
