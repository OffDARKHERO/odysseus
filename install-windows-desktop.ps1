#Requires -Version 5.1
<#
  install-windows-desktop.ps1

  Instalador "todo en uno" para Windows. Tras clonar el repo, ejecuta este
  script UNA vez y deja Odysseus listo con:
    - venv + dependencias + cuenta admin (setup.py)
    - servidor ChromaDB local (memoria + RAG) en su propio venv
    - modelo de embeddings multilingue (mejor en espanol)
    - Browser MCP (si hay Node/npx) para navegacion web del agente
    - icono del barquito + lanzador con splash + ventana independiente (PWA)
    - acceso directo en el escritorio

  Uso (PowerShell en la carpeta del repo):
    powershell -ExecutionPolicy Bypass -File .\install-windows-desktop.ps1

  Es seguro re-ejecutarlo: salta lo que ya existe.
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

# ---------- 1. Buscar Python 3.11+ ----------
Step "Buscando Python 3.11+"
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
if (-not $py) { throw "No se encontro Python 3.11+. Instalalo desde https://www.python.org/downloads/ y reintenta." }
Info ("Python: " + $py + " " + ($pyArgs -join ' '))

# ---------- 2. venv principal + deps + setup ----------
$venvPy = Join-Path $root 'venv\Scripts\python.exe'
if (-not (Test-Path $venvPy)) {
    Step "Creando venv e instalando dependencias (tarda unos minutos)"
    & $py @pyArgs -m venv venv
    & $venvPy -m pip install --upgrade pip --quiet
    & $venvPy -m pip install -r requirements.txt
} else { Info "venv ya existe - omitido" }

if (-not (Test-Path (Join-Path $root 'data\auth.json'))) {
    Step "Primera configuracion (crea data/, base de datos y cuenta admin)"
    Info "Te pedira un usuario y contrasena de administrador:"
    & $venvPy setup.py
} else { Info "Ya configurado (data/auth.json existe) - omitido setup" }

# ---------- 3. Servidor ChromaDB (memoria + RAG) ----------
$chromaExe = Join-Path $root 'venv-chroma\Scripts\chroma.exe'
if (-not (Test-Path $chromaExe)) {
    Step "Instalando servidor ChromaDB (venv aparte)"
    & $py @pyArgs -m venv venv-chroma
    & (Join-Path $root 'venv-chroma\Scripts\python.exe') -m pip install --upgrade pip --quiet
    & (Join-Path $root 'venv-chroma\Scripts\python.exe') -m pip install chromadb
} else { Info "ChromaDB ya instalado - omitido" }

# ---------- 4. Modelo de embeddings multilingue ----------
$envFile = Join-Path $root '.env'
$embedModel = 'sentence-transformers/paraphrase-multilingual-mpnet-base-v2'
if (Test-Path $envFile) {
    $envText = Get-Content $envFile -Raw
    if ($envText -notmatch '(?m)^\s*FASTEMBED_MODEL=') {
        Step "Configurando modelo de embeddings multilingue en .env"
        Add-Content -Path $envFile -Value ("`r`nFASTEMBED_MODEL=" + $embedModel)
        Info "Anadido FASTEMBED_MODEL"
    } else { Info "FASTEMBED_MODEL ya esta en .env - omitido" }
}
if (-not $SkipEmbedDownload) {
    Step "Descargando modelo de embeddings (1 GB, una sola vez)"
    & $venvPy -c "from fastembed import TextEmbedding; list(TextEmbedding(model_name='$embedModel', cache_dir='data/fastembed_cache').embed(['hola']))"
    Info "Embeddings listos"
}

# ---------- 5. Browser MCP (opcional) ----------
if (-not $SkipBrowserMcp) {
    $npx = Get-Command npx -ErrorAction SilentlyContinue
    if ($npx) {
        Step "Instalando Browser MCP (navegacion web del agente, ~300 MB)"
        & $npx.Source -y '@playwright/mcp@latest' --version
    } else {
        Warn "Node/npx no encontrado - se omite Browser MCP (opcional)."
        Warn "Instala Node.js si quieres que el agente navegue la web."
    }
}

# ---------- 6. Icono del barquito ----------
Step "Generando icono de Odysseus"
& $venvPy (Join-Path $root 'scripts\make_icon.py') $root

# ---------- 7. Lanzador silencioso (VBS con ruta dinamica) ----------
Step "Creando lanzador silencioso"
$launcherPs1 = Join-Path $root 'Odysseus-launcher.ps1'
if (-not (Test-Path $launcherPs1)) { Warn "Falta Odysseus-launcher.ps1 en el repo." }
$vbsContent = 'Set s = CreateObject("WScript.Shell")' + "`r`n" + `
  's.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""' + $launcherPs1 + '""", 0, False' + "`r`n"
[System.IO.File]::WriteAllText((Join-Path $root 'Odysseus-silent.vbs'), $vbsContent, [System.Text.Encoding]::ASCII)
Info "Odysseus-silent.vbs creado"

# ---------- 8. Acceso directo en el escritorio ----------
Step "Creando acceso directo en el escritorio"
$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'Odysseus.lnk'
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
$lnk.Arguments = '"' + (Join-Path $root 'Odysseus-silent.vbs') + '"'
$lnk.WorkingDirectory = $root
$lnk.IconLocation = (Join-Path $root 'odysseus.ico') + ',0'
$lnk.Description = 'Iniciar Odysseus'
$lnk.WindowStyle = 7
$lnk.Save()
Info ("Acceso directo: " + $lnkPath)

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Listo. Haz doble clic en 'Odysseus' del escritorio." -ForegroundColor Green
Write-Host "  (Para chatear, abre LM Studio con un modelo cargado)" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
