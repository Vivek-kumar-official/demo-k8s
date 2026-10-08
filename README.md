# demo-k8s

This repo contains a tiny HTTP service, Kubernetes manifests, and scripts to demonstrate a safe rollout, a slow-ready release, a broken release, and recovery.

See `runbook.md` for a concise step-by-step runbook, and `scripts/collect_artifacts.ps1` to bundle logs and artifacts after running the experiment.

Files of interest:
- `app.py` — the service
- `Dockerfile` — builds the container image used by the deployment
- `k8s/deployment.yaml`, `k8s/service.yaml` — Kubernetes manifests
- `scripts/*` — helper scripts: build, deploy, start/stop traffic, rollout
- `tools/analyze_traffic.py` — analyze `traffic.log` to summarize requests and versions seen
