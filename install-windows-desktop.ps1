#Requires -Version 5.1
<#
  install-windows-desktop.ps1

  All-in-one installer for Windows. After cloning the repo, run this script ONCE
  and Odysseus is left ready with:
    - venv + dependencies + admin account (setup.py)
    - a local ChromaDB server (memory + RAG) in its own venv
    - a multilingual embedding model (better for non-English text)
    - the Browser MCP (if Node/npx is present) for agent web browsing
    - the boat icon + a launcher with splash, standalone window (PWA) and tray
    - a desktop shortcut

  Usage (PowerShell in the repo folder):
    powershell -ExecutionPolicy Bypass -File .\install-windows-desktop.ps1

  Safe to re-run: it skips whatever already exists.
#>
param(
    [switch]$SkipBrowserMcp,
    [switch]$SkipEmbedDownload
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

function Step($m) { Write-Host ""; Write-Host ("==> " + $m) -ForegroundColor Cyan }
function Info($m) { Write-Host ("    " + $m) -ForegroundColor Gray }
function Warn($m) { Write-Host ("    " + $m) -ForegroundColor Yellow }

# ---------- 1. Find Python 3.11+ ----------
Step "Looking for Python 3.11+"
$py = $null; $pyArgs = @()
$launcher = Get-Command py -ErrorAction SilentlyContinue
if ($launcher) {
    foreach ($v in @('-3.13','-3.12','-3.11')) {
        $ok = (& $launcher.Source $v -c "import sys;print(sys.version_info[:2]>=(3,11))" 2>$null)
        if ($ok -match 'True') { $py = $launcher.Source; $pyArgs = @($v); break }
    }
}
if (-not $py) {
    $pc = Get-Command python -ErrorAction SilentlyContinue
    if ($pc) {
        $ok = (& $pc.Source -c "import sys;print(sys.version_info[:2]>=(3,11))" 2>$null)
        if ($ok -match 'True') { $py = $pc.Source }
    }
}
if (-not $py) { throw "Python 3.11+ not found. Install it from https://www.python.org/downloads/ and retry." }
Info ("Python: " + $py + " " + ($pyArgs -join ' '))

# ---------- 2. Main venv + deps + setup ----------
$venvPy = Join-Path $root 'venv\Scripts\python.exe'
if (-not (Test-Path $venvPy)) {
    Step "Creating venv and installing dependencies (takes a few minutes)"
    & $py @pyArgs -m venv venv
    & $venvPy -m pip install --upgrade pip --quiet
    & $venvPy -m pip install -r requirements.txt
} else { Info "venv already exists - skipped" }

if (-not (Test-Path (Join-Path $root 'data\auth.json'))) {
    Step "First-time setup (creates data/, the database and an admin account)"
    Info "It will ask you for an admin username and password:"
    & $venvPy setup.py
} else { Info "Already configured (data/auth.json exists) - setup skipped" }

# ---------- 3. ChromaDB server (memory + RAG) ----------
$chromaExe = Join-Path $root 'venv-chroma\Scripts\chroma.exe'
if (-not (Test-Path $chromaExe)) {
    Step "Installing the ChromaDB server (separate venv)"
    & $py @pyArgs -m venv venv-chroma
    & (Join-Path $root 'venv-chroma\Scripts\python.exe') -m pip install --upgrade pip --quiet
    & (Join-Path $root 'venv-chroma\Scripts\python.exe') -m pip install chromadb
} else { Info "ChromaDB already installed - skipped" }

# ---------- 4. Multilingual embedding model ----------
$envFile = Join-Path $root '.env'
$embedModel = 'sentence-transformers/paraphrase-multilingual-mpnet-base-v2'
if (Test-Path $envFile) {
    $envText = Get-Content $envFile -Raw
    if ($envText -notmatch '(?m)^\s*FASTEMBED_MODEL=') {
        Step "Setting the multilingual embedding model in .env"
        Add-Content -Path $envFile -Value ("`r`nFASTEMBED_MODEL=" + $embedModel)
        Info "Added FASTEMBED_MODEL"
    } else { Info "FASTEMBED_MODEL already in .env - skipped" }
}
if (-not $SkipEmbedDownload) {
    Step "Downloading the embedding model (1 GB, one time)"
    & $venvPy -c "from fastembed import TextEmbedding; list(TextEmbedding(model_name='$embedModel', cache_dir='data/fastembed_cache').embed(['hello']))"
    Info "Embeddings ready"
}

# ---------- 5. Browser MCP (optional) ----------
if (-not $SkipBrowserMcp) {
    $npx = Get-Command npx -ErrorAction SilentlyContinue
    if ($npx) {
        Step "Installing the Browser MCP (agent web browsing, ~300 MB)"
        & $npx.Source -y '@playwright/mcp@latest' --version
    } else {
        Warn "Node/npx not found - skipping the Browser MCP (optional)."
        Warn "Install Node.js if you want the agent to browse the web."
    }
}

# ---------- 6. Boat icon ----------
Step "Generating the Odysseus icon"
& $venvPy (Join-Path $root 'scripts\make_icon.py') $root

# ---------- 7. Silent launcher (VBS with dynamic path) ----------
Step "Creating the silent launcher"
$launcherPs1 = Join-Path $root 'Odysseus-launcher.ps1'
if (-not (Test-Path $launcherPs1)) { Warn "Odysseus-launcher.ps1 is missing from the repo." }
$vbsContent = 'Set s = CreateObject("WScript.Shell")' + "`r`n" + `
  's.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $launcherPs1 + '""", 0, False' + "`r`n"
[System.IO.File]::WriteAllText((Join-Path $root 'Odysseus-silent.vbs'), $vbsContent, [System.Text.Encoding]::ASCII)
Info "Odysseus-silent.vbs created"

# ---------- 8. Desktop shortcut ----------
Step "Creating the desktop shortcut"
$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'Odysseus.lnk'
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
$lnk.Arguments = '"' + (Join-Path $root 'Odysseus-silent.vbs') + '"'
$lnk.WorkingDirectory = $root
$lnk.IconLocation = (Join-Path $root 'odysseus.ico') + ',0'
$lnk.Description = 'Start Odysseus'
$lnk.WindowStyle = 7
$lnk.Save()
Info ("Shortcut: " + $lnkPath)

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Done. Double-click 'Odysseus' on your desktop." -ForegroundColor Green
Write-Host "  (To chat, open LM Studio with a model loaded)" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
