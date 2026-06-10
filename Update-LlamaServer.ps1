# ============================================================================
# Update-LlamaServer.ps1 - shared llama.cpp (llama-server) version checker /
# updater for C:\Odysseus\llama-win. Used by Odysseus-Dashboard AND Aether.
#
#   -Check    : compare local build vs latest GitHub release (1 API call).
#               NEVER updates anything. Default action when no switch given.
#   -Update   : backup llama-win -> llama-win.prev, download latest CUDA win
#               x64 build, swap, carry over CUDA runtime DLLs, verify, and
#               roll back automatically if the new binary fails.
#   -Restore  : swap llama-win.prev back in (undo the last update).
#   -Force    : with -Update, reinstall even if already up to date.
#
# Output is human-readable PLUS stable KEY=VALUE lines for the dashboard /
# Aether to parse:  LOCAL_BUILD, REMOTE_BUILD, UPDATE_AVAILABLE, RESULT, ...
# RESULT is one of: CHECK_OK | UP_TO_DATE | UPDATED | RESTORED | FAILED
#
# Notes:
#  - GitHub API unauthenticated = 60 req/h -> only call on user click.
#  - This script NEVER auto-updates silently: -Update is an explicit action.
#  - PowerShell 5.1 compatible (no &&, no ternary).
# ============================================================================
param(
    [switch]$Check,
    [switch]$Update,
    [switch]$Restore,
    [switch]$Force,
    [string]$InstallDir = 'C:\Odysseus\llama-win'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoApi  = 'https://api.github.com/repos/ggml-org/llama.cpp/releases/latest'
$PrevDir  = "$InstallDir.prev"
$Headers  = @{ 'User-Agent' = 'Odysseus-LlamaUpdater'; 'Accept' = 'application/vnd.github+json' }

function Get-LocalBuild {
    $exe = Join-Path $InstallDir 'llama-server.exe'
    if (-not (Test-Path $exe)) { return 0 }
    # cmd /c keeps native stderr as plain text (PS 5.1 would wrap it in ErrorRecords)
    $out = cmd /c "`"$exe`" --version 2>&1" | Out-String
    if ($out -match 'version:\s*(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-RemoteRelease {
    $rel = Invoke-RestMethod -Uri $RepoApi -Headers $Headers -TimeoutSec 30
    $build = 0
    if ($rel.tag_name -match '(\d+)') { $build = [int]$Matches[1] }
    # pick the windows x64 CUDA build (not the cudart runtime package)
    $asset = $rel.assets | Where-Object {
        $_.name -match 'bin-win.*cuda.*x64.*\.zip$' -and $_.name -notmatch '^cudart'
    } | Sort-Object { if ($_.name -match '12') { 0 } else { 1 } } | Select-Object -First 1
    return @{ Tag = $rel.tag_name; Build = $build; Asset = $asset }
}

function Stop-LlamaServer {
    $p = Get-Process llama-server -ErrorAction SilentlyContinue
    if ($p) {
        $p | Stop-Process -Force -Confirm:$false
        Start-Sleep -Milliseconds 800
        return $true
    }
    return $false
}

# ---------------------------------------------------------------- RESTORE --
if ($Restore) {
    if (-not (Test-Path $PrevDir)) {
        Write-Output 'No llama-win.prev backup found - nothing to restore.'
        Write-Output 'RESULT=FAILED'
        exit 1
    }
    $wasRunning = Stop-LlamaServer
    $broken = "$InstallDir.broken"
    if (Test-Path $broken) { Remove-Item $broken -Recurse -Force -Confirm:$false }
    if (Test-Path $InstallDir) { Rename-Item $InstallDir $broken }
    Rename-Item $PrevDir $InstallDir
    $b = Get-LocalBuild
    Write-Output "Restored previous install (build $b). Current one kept at llama-win.broken."
    Write-Output "LOCAL_BUILD=$b"
    Write-Output "SERVER_WAS_RUNNING=$wasRunning"
    Write-Output 'RESULT=RESTORED'
    exit 0
}

# ------------------------------------------------------------------ CHECK --
$local = Get-LocalBuild
try {
    $remote = Get-RemoteRelease
} catch {
    Write-Output "Could not reach GitHub: $($_.Exception.Message)"
    Write-Output "LOCAL_BUILD=$local"
    Write-Output 'RESULT=FAILED'
    exit 1
}
$available = ($remote.Build -gt $local)
Write-Output "Local llama-server build : $local"
Write-Output "Latest release           : $($remote.Tag) (build $($remote.Build))"
Write-Output "LOCAL_BUILD=$local"
Write-Output "REMOTE_BUILD=$($remote.Build)"
Write-Output "REMOTE_TAG=$($remote.Tag)"
Write-Output "UPDATE_AVAILABLE=$($available.ToString().ToLower())"

if (-not $Update) {
    Write-Output 'RESULT=CHECK_OK'
    exit 0
}

# ------------------------------------------------------------------ UPDATE --
if (-not $available -and -not $Force) {
    Write-Output 'Already up to date.'
    Write-Output 'RESULT=UP_TO_DATE'
    exit 0
}
if ($null -eq $remote.Asset) {
    Write-Output 'No matching win-cuda-x64 asset in the latest release.'
    Write-Output 'RESULT=FAILED'
    exit 1
}

$tmp = Join-Path $env:TEMP 'llama-update'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }
$zipPath = Join-Path $tmp $remote.Asset.name
Write-Output "Downloading $($remote.Asset.name) ($([math]::Round($remote.Asset.size/1MB)) MB)..."
Invoke-WebRequest -Uri $remote.Asset.browser_download_url -Headers @{ 'User-Agent' = 'Odysseus-LlamaUpdater' } -OutFile $zipPath -TimeoutSec 900

# sanity: the zip must contain llama-server.exe
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
$hasServer = $false
foreach ($e in $zip.Entries) { if ($e.Name -eq 'llama-server.exe') { $hasServer = $true } }
$zip.Dispose()
if (-not $hasServer) {
    Write-Output 'Downloaded zip has no llama-server.exe - aborting (nothing touched).'
    Write-Output 'RESULT=FAILED'
    exit 1
}

$wasRunning = Stop-LlamaServer
if ($wasRunning) { Write-Output 'Stopped the running llama-server.' }

# rotate backup and swap
if (Test-Path $PrevDir) { Remove-Item $PrevDir -Recurse -Force -Confirm:$false }
if (Test-Path $InstallDir) { Rename-Item $InstallDir $PrevDir }
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $InstallDir)
    # llama.cpp release zips don't bundle the CUDA runtime - carry it over
    foreach ($d in 'cudart64_12.dll', 'cublas64_12.dll', 'cublasLt64_12.dll') {
        $dst = Join-Path $InstallDir $d
        $src = Join-Path $PrevDir $d
        if (-not (Test-Path $dst) -and (Test-Path $src)) {
            Copy-Item $src $dst
            Write-Output "Carried over CUDA runtime: $d"
        }
    }
    $newBuild = Get-LocalBuild
    if ($newBuild -lt 1) { throw "new llama-server.exe did not report a version" }
    Write-Output "Updated to build $newBuild. Previous install kept at llama-win.prev."
    if ($wasRunning) { Write-Output 'NOTE: the server was stopped - relaunch it from the dashboard.' }
    Write-Output "LOCAL_BUILD=$newBuild"
    Write-Output "SERVER_WAS_RUNNING=$wasRunning"
    Write-Output 'RESULT=UPDATED'
    Remove-Item $zipPath -Force -Confirm:$false
    exit 0
} catch {
    # rollback: put the previous install back
    Write-Output "Update failed: $($_.Exception.Message) - rolling back."
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force -Confirm:$false }
    if (Test-Path $PrevDir) { Rename-Item $PrevDir $InstallDir }
    Write-Output "LOCAL_BUILD=$(Get-LocalBuild)"
    Write-Output 'RESULT=FAILED'
    exit 1
}
