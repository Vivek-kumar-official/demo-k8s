#!/usr/bin/env bash
set -euo pipefail

POD_NAME=traffic-client
SERVICE_HOST=demo-service
SERVICE_PORT=8080

echo "Starting traffic client pod ($POD_NAME) to curl $SERVICE_HOST:$SERVICE_PORT/version once per second..."

kubectl run "$POD_NAME" --image=curlimages/curl:8.2.1 --restart=Never --overrides='{"spec": {"containers": [{"name":"traffic","image":"curlimages/curl:8.2.1","command":["sh","-c","while true; do date -Is; curl -sS -m 2 http://'$SERVICE_HOST':'$SERVICE_PORT'/version -w " status:%{http_code} time:%{time_total}\n" || echo "curl failed"; sleep 1; done"]}],"restartPolicy":"Never"}}'

echo "Traffic pod started. To stream logs: kubectl logs -f $POD_NAME"
