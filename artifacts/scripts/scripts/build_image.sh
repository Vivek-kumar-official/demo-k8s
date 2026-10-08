#!/usr/bin/env bash
set -euo pipefail

IMAGE=demo-service:1.0

echo "Building image $IMAGE..."
docker build -t "$IMAGE" .

if command -v kind >/dev/null 2>&1; then
  echo "Detected kind; loading image into kind clusters..."
  kind load docker-image "$IMAGE" || true
fi

echo "Built $IMAGE"
