# demo-k8s

This repository demonstrates a safe Kubernetes rollout using a tiny HTTP service. The demo shows three releases:

- `v1`: ready immediately
- `v2`: ready after a configurable delay (simulates slow initialization)
- `v3-broken`: never becomes Ready (simulates a bad release)

The goal: show how readiness probes, `maxUnavailable: 0` and `maxSurge: 1` rolling updates preserve availability, and how Kubernetes behaves when a release fails to become Ready.

See `runbook.md` and `RECORDING_SCRIPT.md` for recording cues and a step-by-step runbook. Use `scripts/collect_artifacts.ps1` at the end of a run to collect diagnostics into `artifacts/` and `artifacts.zip`.

Quick reference — files of interest
- `app.py` — demo service (endpoints: `/health`, `/ready`, `/version`)
- `Dockerfile` — builds `demo-service:<tag>` used for deployments
- `k8s/deployment.yaml`, `k8s/service.yaml` — Deployment (2 replicas) and Service manifests with probes and rolling update strategy
- `traffic-pod.yaml` — in-cluster traffic generator that logs structured request lines to analyze
- `scripts/` — helper scripts:
	- `rollout_update.sh` — wrapper to set envs and wait for rollout (works in bash)
	- `collect_artifacts.ps1` — gather cluster state and logs into `artifacts/` (PowerShell)
	- `record_demo.ps1` — interactive transcript helper for recording
- `tools/analyze_traffic.py` — parse `artifacts/traffic.log` to summarize versions, success/failure counts, and instance distribution

Prerequisites
- Docker Desktop (or equivalent) and a Kubernetes cluster (kind is recommended for the demo)
- `kubectl` configured to talk to the demo cluster
- PowerShell (Windows) or a POSIX shell (Linux/macOS). The repo includes both shell and PowerShell friendly scripts; prefer the correct one for your shell.

Quickstart (one-machine demo)

1. Build image (from project root):
```powershell
docker build -t demo-service:1.0 demo-k8s
# If using kind: kind load docker-image demo-service:1.0 --name demo
```

2. Apply manifests and deploy v1 (ready immediately):
```powershell
kubectl apply -f demo-k8s/k8s/service.yaml
kubectl apply -f demo-k8s/k8s/deployment.yaml
kubectl set env deployment/demo-service APP_VERSION=v1 READY_DELAY_SECONDS=0 NEVER_READY=false
kubectl rollout status deployment/demo-service --timeout=180s
kubectl get pods -l app=demo-service -o wide
```

3. Start traffic generator (in-cluster) and capture logs:
```powershell
kubectl apply -f demo-k8s/traffic-pod.yaml
# to stream logs live:
kubectl logs pod/traffic-client -c traffic -f
# or to capture for later analysis:
kubectl logs pod/traffic-client -c traffic > artifacts/traffic.log
```

Performing rollouts

- Rollout v2 (slow-ready):
```powershell
kubectl set env deployment/demo-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
kubectl rollout status deployment/demo-service --timeout=180s
```
Watch pods in another shell:
```powershell
kubectl get pods -l app=demo-service -w -o wide
kubectl get endpoints demo-service -o yaml
```

- Rollout v3-broken (expected to fail):
```powershell
kubectl set env deployment/demo-service APP_VERSION=v3 READY_DELAY_SECONDS=0 NEVER_READY=true
kubectl rollout status deployment/demo-service --timeout=180s
if ($LASTEXITCODE -ne 0) { Write-Output 'v3 rollout failed (expected)' }
```

Recovery — revert to known-good v2:
```powershell
kubectl set env deployment/demo-service APP_VERSION=v2 READY_DELAY_SECONDS=30 NEVER_READY=false
kubectl rollout status deployment/demo-service --timeout=180s
```

Capturing artifacts

After you finish a demo run, collect a reproducible snapshot for submission or debugging:
```powershell
# remove old artifacts if any
Remove-Item -Recurse -Force artifacts -ErrorAction SilentlyContinue
.\demo-k8s\scripts\collect_artifacts.ps1
```
This creates `artifacts/` and `artifacts.zip` containing `traffic.log`, pod logs, deployment describe, events, and endpoint snapshots.

Recording tips
- Use `RECORDING_SCRIPT.md` as a spoken checklist to hit the required demonstration points (build, deploy v1, start traffic, v2 rollout, v3-broken, recover, summarize).
- Run the `record_demo.ps1` helper to capture a transcript while you narrate if you want time-aligned notes.
- Keep three shells open while recording: rollout commands, pod/watch, and traffic logs.

Troubleshooting
- If rollouts don’t create new pods, inspect the Deployment template — Kubernetes only creates a new ReplicaSet when the pod template changes:
```powershell
kubectl get deployment demo-service -o jsonpath='{.spec.template.spec.containers[0].env}'
kubectl describe deployment demo-service
```
- If the template already matches the target version, force a restart:
```powershell
kubectl rollout restart deployment/demo-service
kubectl rollout status deployment/demo-service --timeout=180s
```
- If `traffic-pod.yaml` was modified, delete the existing traffic pod to recreate it:
```powershell
kubectl delete pod traffic-client --ignore-not-found
kubectl apply -f demo-k8s/traffic-pod.yaml
```
- On Windows/PowerShell: avoid bash `||` idioms; use `$LASTEXITCODE` checks instead (the repo's `RECORDING_SCRIPT.md` has PowerShell-safe examples).

Useful commands
- View latest traffic summary:
```powershell
python demo-k8s/tools/analyze_traffic.py artifacts/traffic.log
```
- Tail traffic and filter last lines:
```powershell
kubectl logs pod/traffic-client -c traffic > artifacts/traffic.log
Get-Content artifacts\traffic.log -Tail 50
```

Repository layout (inner `demo-k8s`):
```
demo-k8s/
	app.py
	Dockerfile
	k8s/
	scripts/
	tools/
	traffic-pod.yaml
	README.md  <-- this file
```

If you want, I can also:
- add a `--clean` flag to `scripts/collect_artifacts.ps1` to auto-delete old artifacts before collecting, or
- merge/remove the outer duplicate folders so there's only a single working tree to avoid confusion.

License: none included — this is a small demo for learning and evaluation.
