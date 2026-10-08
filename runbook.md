# Runbook — demo-k8s rollout exercise

Purpose
- Steps to run the demo, collect evidence, and package the submission.

Prereqs
- Docker Desktop installed and running
- `kubectl` and `kind` installed and on PATH
- Clone of repository; current working dir is the repo root where this file lives

Quick Commands

1) Build image and load into kind (if using kind):

```powershell
docker build -t demo-service:1.0 .
kind load docker-image demo-service:1.0 --name demo
```

2) Deploy v1 (ready immediately):

```powershell
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl set env deployment/demo-service APP_VERSION=v1 READY_DELAY_SECONDS=0 NEVER_READY=false
kubectl rollout status deployment/demo-service --timeout=120s
kubectl get pods -l app=demo-service -o wide > pods-v1.txt
kubectl describe deployment demo-service > deployment-v1-describe.txt
```

3) Start traffic client (records to `traffic.log`):

```powershell
# apply the bundled traffic pod which emits structured per-second logs to stdout
kubectl apply -f traffic-pod.yaml
# collect the authoritative traffic log (do not rely on -f in background)
kubectl logs pod/traffic-client -c traffic > traffic.log
```

4) Roll to `v2` (30s readiness delay) while traffic runs:

```powershell
kubectl set env deployment/demo-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
kubectl rollout status deployment/demo-service --timeout=180s
kubectl get pods -l app=demo-service -o wide > pods-v2.txt
kubectl describe deployment demo-service > deployment-v2-describe.txt
```

5) Roll to `v3-broken` (never ready) and capture diagnostics:

```powershell
kubectl set env deployment/demo-service APP_VERSION=v3-broken READY_DELAY_SECONDS=0 NEVER_READY=true
kubectl rollout status deployment/demo-service --timeout=180s || echo "rollout failed/timed out"

kubectl get pods -l app=demo-service -o wide > pods-v3.txt
kubectl describe deployment demo-service > deployment-v3-describe.txt
kubectl describe pod -l app=demo-service > pods-v3-describe.txt
kubectl get endpoints demo-service -o yaml > endpoints-v3.yaml
kubectl get events --sort-by=.metadata.creationTimestamp | tail -n 100 > events-v3.txt
```

6) Recover to `v2`:

```powershell
kubectl set env deployment/demo-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
kubectl rollout status deployment/demo-service --timeout=180s
kubectl get pods -l app=demo-service -o wide > pods-recovered.txt
kubectl describe deployment demo-service > deployment-recovered-describe.txt
```

7) Stop traffic and collect logs:

```powershell
kubectl logs pod/traffic-client -c traffic > traffic.log || true
kubectl delete pod traffic-client --ignore-not-found
```

Evidence to include
- `artifacts/traffic.log` — timestamped per-second structured requests
- `artifacts/pods-v3.txt`, `artifacts/pods-v3-describe.txt`, `artifacts/deployment-v3-describe.txt`, `artifacts/events-v3.txt`, `artifacts/endpoints-v3.yaml`

Alert suggestion
- Name: Deployment rollout stalled
- Condition: No new ready replicas for deployment `demo-service` within 3 minutes of rollout start
- First action: Inspect `kubectl describe deployment demo-service`, `kubectl get events`, and pause/rollback.

Notes
- The provided `scripts/` include helpers to build, deploy, rollout, start/stop traffic and collect artifacts. Use `scripts/collect_artifacts.ps1` to bundle logs after the run.
