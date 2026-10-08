<#
Recording helper for the demo. This script does NOT execute cluster-changing
commands automatically; it starts a transcript (text capture) and prints the
exact commands to run while you record video+voice (e.g., OBS or Xbox Game
Bar). Press Enter to advance between steps so you can speak the narration.

Run from PowerShell in the repo root:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\record_demo.ps1

It will write a transcript to ./artifacts/recording-transcript.txt
#>

param(
    [string]$outDir = "..\artifacts"
)

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$trans = Join-Path $outDir "recording-transcript.txt"
Start-Transcript -Path $trans -Force

function PauseAndSay($title, $prompt) {
    Write-Host ""; Write-Host "==== $title ====" -ForegroundColor Cyan
    Write-Host $prompt -ForegroundColor Yellow
    Write-Host "Command(s):" -ForegroundColor Green
}

# Intro
PauseAndSay "Intro" "Say your name, objective, and what the demo will show (30s)."
Read-Host "(When ready, press Enter to continue)"

# Environment & versions
PauseAndSay "Environment" "Show tool versions: Docker, kind, kubectl."
Write-Host "docker --version; kubectl version --client --short; kind --version" -ForegroundColor Gray
Read-Host "Run the commands and narrate their output, then press Enter"

# Build image
PauseAndSay "Build image" "Build the container image used for all releases. Narrate the Dockerfile choices."
Write-Host "cd demo-k8s; docker build -t demo-service:1.0 ." -ForegroundColor Gray
Read-Host "Run the build (or run from WSL), then press Enter"

# Deploy v1
PauseAndSay "Deploy v1" "Apply manifests for v1 (APP_VERSION=v1 READY_DELAY_SECONDS=0). Show pod READY state."
Write-Host "kubectl apply -f k8s/service.yaml; kubectl apply -f k8s/deployment.yaml\nkubectl set env deployment/demo-service APP_VERSION=v1 READY_DELAY_SECONDS=0 NEVER_READY=false\nkubectl rollout status deployment/demo-service --timeout=180s" -ForegroundColor Gray
Read-Host "Run these commands and narrate; when pods are Ready press Enter"

# Start traffic
PauseAndSay "Start traffic" "Start the in-cluster traffic client and begin logging. Explain the client config (1 req/s, 2s timeout)."
Write-Host "kubectl apply -f traffic-pod.yaml\nkubectl logs -f pod/traffic-client -c traffic --since=1s > traffic.log &" -ForegroundColor Gray
Read-Host "Start traffic and confirm logs are being produced, then press Enter"

# Rollout v2
PauseAndSay "Rollout v2" "Trigger v2 (READY_DELAY_SECONDS=30) while traffic runs; narrate expected behavior and probes."
Write-Host "./scripts/rollout_update.sh v2" -ForegroundColor Gray
Read-Host "Run the rollout script; narrate the rollout status until it succeeds, then press Enter"

# Observe v2 serving
PauseAndSay "Observe v2" "Show that v2 pods become Ready after ~30s and serve /version through the Service."
Write-Host "kubectl get pods -l app=demo-service -o wide\nkubectl exec -it pod/traffic-client -c traffic -- tail -n 50 /traffic.log" -ForegroundColor Gray
Read-Host "Show traffic.log entries for v2, narrate, then press Enter"

# Rollout v3-broken
PauseAndSay "Rollout v3-broken" "Trigger the broken release (NEVER_READY=true) while traffic runs. Explain what you expect."
Write-Host "./scripts/rollout_update.sh v3-broken || echo 'v3 rollout failed (expected)'; kubectl get pods -l app=demo-service -o wide" -ForegroundColor Gray
Read-Host "Run the rollout script; narrate probe failures and events, then press Enter"

# Collect diagnostics
PauseAndSay "Collect diagnostics" "Show events, deployment describe, pod logs, and Service endpoints."
Write-Host "kubectl describe deployment demo-service\nkubectl describe pod -l app=demo-service\nkubectl get endpoints demo-service -o yaml\nkubectl get events --sort-by=.metadata.creationTimestamp | tail -n 100" -ForegroundColor Gray
Read-Host "Run these and narrate findings (e.g., readiness probe failures), then press Enter"

# Recover to v2
PauseAndSay "Recover" "Recover to v2 and verify rollout completes and traffic returns to normal."
Write-Host "./scripts/rollout_update.sh v2\nkubectl rollout status deployment/demo-service" -ForegroundColor Gray
Read-Host "Run recovery commands and narrate success, then press Enter"

# Final summary
PauseAndSay "Summary" "Summarize results: total requests, successes, failures, versions observed, and recommendations (30s)."
Write-Host "python tools/analyze_traffic.py traffic.log" -ForegroundColor Gray
Read-Host "Run the analyzer and narrate the conclusions, then press Enter"

Stop-Transcript
Write-Host "Transcript saved to: $trans" -ForegroundColor Green
Write-Host "Recording helper finished. Use OBS or Xbox Game Bar to record screen+voice while you follow these steps." -ForegroundColor Cyan
