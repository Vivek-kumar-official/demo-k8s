#!/usr/bin/env bash
set -euo pipefail

POD_NAME=traffic-client
echo "Stopping traffic pod $POD_NAME and printing logs..."
kubectl logs "$POD_NAME" || true
kubectl delete pod "$POD_NAME" --ignore-not-found
