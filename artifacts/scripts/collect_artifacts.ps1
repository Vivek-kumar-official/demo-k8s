param(
    [string]$outDir = "artifacts"
)
Set-StrictMode -Version Latest
if (-Not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Collect common artifacts if tools available
try {
    kubectl version --client --short > "$outDir/kubectl-version.txt" 2>&1
} catch { "kubectl missing" | Out-File "$outDir/kubectl-version.txt" }

# pods and deployment
& kubectl get pods -l app=demo-service -o wide > "$outDir/pods.txt" 2>&1
if ($LASTEXITCODE -ne 0) { "kubectl get pods failed (exit=$LASTEXITCODE)" | Out-File "$outDir/pods.txt" -Append }

& kubectl describe deployment demo-service > "$outDir/deployment-describe.txt" 2>&1
if ($LASTEXITCODE -ne 0) { "kubectl describe deployment failed (exit=$LASTEXITCODE)" | Out-File "$outDir/deployment-describe.txt" -Append }

# endpoints and events
& kubectl get endpoints demo-service -o yaml > "$outDir/endpoints.yaml" 2>&1
if ($LASTEXITCODE -ne 0) { "kubectl get endpoints failed (exit=$LASTEXITCODE)" | Out-File "$outDir/endpoints.yaml" -Append }

# get last 200 events (PowerShell native)
try {
    kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 200 | Out-File "$outDir/events.txt"
    if ($LASTEXITCODE -ne 0) { "kubectl get events failed (exit=$LASTEXITCODE)" | Out-File "$outDir/events.txt" -Append }
} catch {
    "kubectl get events failed: $_" | Out-File "$outDir/events.txt" -Append
}

# traffic log if present
if (Test-Path "traffic.log") { Copy-Item -Path "traffic.log" -Destination "$outDir/traffic.log" -Force }

# include scripts and manifests
Copy-Item -Path "k8s" -Destination "$outDir/k8s" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "scripts" -Destination "$outDir/scripts" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "app.py" -Destination "$outDir/app.py" -Force -ErrorAction SilentlyContinue

# zip
$zip = "$outDir.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory((Resolve-Path $outDir).Path, $zip)
Write-Host "Created $zip"
