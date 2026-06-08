# Odysseus - lanzador grafico para Windows
# Muestra un splash mientras arranca ChromaDB + servidor, espera a que el
# servidor responda y SOLO entonces abre el navegador. Deja un icono en la
# bandeja del sistema para abrir/detener (la consola queda oculta).

$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$accent = [System.Drawing.Color]::FromArgb(224,108,117)
$bg     = [System.Drawing.Color]::FromArgb(24,27,33)
$muted  = [System.Drawing.Color]::FromArgb(150,160,170)

# ---------- Splash ----------
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.StartPosition   = 'CenterScreen'
$form.Size            = New-Object System.Drawing.Size(440,260)
$form.BackColor       = $bg
$form.TopMost         = $true
$form.ShowInTaskbar   = $false

$pic = New-Object System.Windows.Forms.PictureBox
$pic.SizeMode = 'Zoom'
$pic.Size     = New-Object System.Drawing.Size(96,96)
$pic.Location = New-Object System.Drawing.Point(172,28)
$pic.BackColor = 'Transparent'
$iconPng = Join-Path $root 'odysseus-icon-preview.png'
if (Test-Path $iconPng) { $pic.Image = [System.Drawing.Image]::FromFile($iconPng) }
$form.Controls.Add($pic)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Odysseus'
$title.ForeColor = $accent
$title.Font = New-Object System.Drawing.Font('Segoe UI',22,[System.Drawing.FontStyle]::Bold)
$title.TextAlign = 'MiddleCenter'
$title.Size = New-Object System.Drawing.Size(440,42)
$title.Location = New-Object System.Drawing.Point(0,134)
$title.BackColor = 'Transparent'
$form.Controls.Add($title)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Iniciando...'
$status.ForeColor = $muted
$status.Font = New-Object System.Drawing.Font('Segoe UI',10)
$status.TextAlign = 'MiddleCenter'
$status.Size = New-Object System.Drawing.Size(440,26)
$status.Location = New-Object System.Drawing.Point(0,184)
$status.BackColor = 'Transparent'
$form.Controls.Add($status)

$form.Show()
$form.Refresh()

function Set-Status($t) {
    $status.Text = $t
    $status.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

# Abrir Odysseus en una VENTANA INDEPENDIENTE (modo app PWA, sin pestanas ni
# barra de direcciones). Detecta Chrome o Edge; si no hay, usa el navegador por
# defecto como respaldo.
$script:appUrl = 'http://127.0.0.1:7000'
function Open-OdysseusWindow {
    $candidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )
    $browser = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($browser) {
        Start-Process -FilePath $browser -ArgumentList @("--app=$($script:appUrl)","--new-window")
    } else {
        Start-Process $script:appUrl
    }
}

# ---------- Si ya esta corriendo, solo abrir ----------
$already = Get-NetTCPConnection -LocalPort 7000 -State Listen -ErrorAction SilentlyContinue
if ($already) {
    Set-Status 'Odysseus ya estaba abierto'
    Open-OdysseusWindow
    Start-Sleep -Milliseconds 800
    $form.Close()
    return
}

# ---------- ChromaDB ----------
Set-Status 'Iniciando memoria (ChromaDB)...'
$chromaPid = $null
$chromaUp = Get-NetTCPConnection -LocalPort 8100 -State Listen -ErrorAction SilentlyContinue
$chromaExe = Join-Path $root 'venv-chroma\Scripts\chroma.exe'
if (-not $chromaUp -and (Test-Path $chromaExe)) {
    $p = Start-Process -WindowStyle Hidden -PassThru -FilePath $chromaExe `
        -ArgumentList @('run','--host','127.0.0.1','--port','8100','--path',(Join-Path $root 'data\chroma'))
    $chromaPid = $p.Id
    Start-Sleep -Seconds 3
}

# ---------- Servidor Odysseus (oculto) ----------
Set-Status 'Arrancando servidor...'
$venvPy = Join-Path $root 'venv\Scripts\python.exe'
$ody = Start-Process -WindowStyle Hidden -PassThru -FilePath $venvPy `
    -ArgumentList @('-m','uvicorn','app:app','--host','127.0.0.1','--port','7000')
$odyPid = $ody.Id

# ---------- Esperar a que responda ----------
Set-Status 'Esperando al servidor...'
$ready = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Milliseconds 700
    try {
        Invoke-WebRequest -Uri 'http://127.0.0.1:7000/' -UseBasicParsing -TimeoutSec 2 -MaximumRedirection 0 -ErrorAction Stop | Out-Null
        $ready = $true; break
    } catch {
        if ($_.Exception.Response) { $ready = $true; break }  # 302 login = listo
    }
    if ($i -eq 8)  { Set-Status 'Cargando modulos (memoria, RAG, MCP)...' }
    if ($i -eq 25) { Set-Status 'Casi listo...' }
    [System.Windows.Forms.Application]::DoEvents()
}

if ($ready) {
    Set-Status 'Listo - abriendo Odysseus'
    Open-OdysseusWindow
    Start-Sleep -Milliseconds 700
} else {
    Set-Status 'El servidor tardo demasiado. Abriendo de todos modos...'
    Open-OdysseusWindow
    Start-Sleep -Seconds 2
}
$form.Hide()

# ---------- Icono en bandeja del sistema ----------
$notify = New-Object System.Windows.Forms.NotifyIcon
$icoPath = Join-Path $root 'odysseus.ico'
if (Test-Path $icoPath) { $notify.Icon = New-Object System.Drawing.Icon($icoPath) }
else { $notify.Icon = [System.Drawing.SystemIcons]::Application }
$notify.Text = 'Odysseus (en ejecucion)'
$notify.Visible = $true
$notify.ShowBalloonTip(2500,'Odysseus','Servidor en marcha en http://127.0.0.1:7000',[System.Windows.Forms.ToolTipIcon]::Info)

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen = $menu.Items.Add('Abrir Odysseus')
$miStop = $menu.Items.Add('Detener Odysseus')
$notify.ContextMenuStrip = $menu

$openAction = { Open-OdysseusWindow }
$miOpen.Add_Click($openAction)
$notify.Add_DoubleClick($openAction)

$stopAction = {
    foreach ($procId in @($script:odyPid, $script:chromaPid)) {
        if ($procId) { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue }
    }
    # respaldo: liberar puertos por si los PID cambiaron
    foreach ($port in 7000,8100) {
        $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($c) { $c | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } }
    }
    $notify.Visible = $false
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
}
$miStop.Add_Click($stopAction)

$form.Close()
[System.Windows.Forms.Application]::Run()
