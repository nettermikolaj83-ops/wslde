<#
.SYNOPSIS
    Uruchamia zewnetrzny X Server (VcXsrv) i pelna sesje pulpitu XFCE w Ubuntu (WSL2).
    Uruchamiane przez dwuklik - nie wymaga wpisywania zadnych komend.

.NOTES
    Bezpieczne przy wielokrotnym klikaniu: jesli X Server i/lub sesja XFCE juz dzialaja,
    skrypt nie uruchamia ich ponownie.
#>

[CmdletBinding()]
param(
    [string] $DistroPattern = 'Ubuntu*',
    [int]    $DisplayNum = 0,
    [switch] $Windowed          # domyslnie pelny ekran; -Windowed dla dużego okna zamiast fullscreen
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    $msg" -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "    $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Znajdz zainstalowana dystrybucje Ubuntu
# ---------------------------------------------------------------------------
function Get-UbuntuDistro {
    param([string]$Pattern)
    $names = & wsl.exe -l -q 2>$null |
        ForEach-Object { ($_ -replace "`0", '').Trim() } |
        Where-Object { $_ -ne '' }
    $match = $names | Where-Object { $_ -like $Pattern } | Select-Object -First 1
    if (-not $match) {
        throw "Nie znaleziono zainstalowanej dystrybucji WSL odpowiadajacej wzorcowi '$Pattern'. Zainstaluj Ubuntu (patrz Install-Prerequisites.ps1) i sprobuj ponownie."
    }
    return $match
}

# ---------------------------------------------------------------------------
# 2. Znajdz VcXsrv
# ---------------------------------------------------------------------------
function Get-VcXsrvExe {
    $candidates = @(
        "$Env:ProgramFiles\VcXsrv\vcxsrv.exe",
        "${Env:ProgramFiles(x86)}\VcXsrv\vcxsrv.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $cmd = Get-Command vcxsrv.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# ---------------------------------------------------------------------------
# 3. Sprawdzanie portu (czy X Server juz nasluchuje)
# ---------------------------------------------------------------------------
function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 500)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $task = $client.ConnectAsync($HostName, $Port)
        $ok = $task.Wait($TimeoutMs)
        $result = $ok -and $client.Connected
        $client.Close()
        return [bool]$result
    } catch {
        return $false
    }
}

function Wait-ForXServer {
    param([int]$Port, [int]$TimeoutSec = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-TcpPort -HostName '127.0.0.1' -Port $Port -TimeoutMs 500) { return $true }
        Start-Sleep -Milliseconds 400
    }
    return $false
}

# ---------------------------------------------------------------------------
# 4. Uruchom X Server (jesli nie dziala)
# ---------------------------------------------------------------------------
$xPort = 6000 + $DisplayNum
$vcxsrvRunning = [bool](Get-Process -Name 'vcxsrv' -ErrorAction SilentlyContinue)

if ($vcxsrvRunning) {
    Write-Step "X Server (VcXsrv) juz dziala - pomijam uruchamianie."
} else {
    Write-Step "Uruchamiam X Server (VcXsrv)..."
    $vcxsrvExe = Get-VcXsrvExe
    if (-not $vcxsrvExe) {
        Write-Err2 "VcXsrv nie jest zainstalowany. Uruchom najpierw Install-Prerequisites.ps1."
        exit 1
    }

    if ($Windowed) {
        Add-Type -AssemblyName System.Windows.Forms
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $w = [int]($b.Width * 0.9)
        $h = [int]($b.Height * 0.9)
        $screenArgs = @('-screen', '0', "${w}x${h}")
    } else {
        $screenArgs = @('-fullscreen')
    }

    $vcxsrvArgs = @(":$DisplayNum", '-ac', '-clipboard', '-wgl', '-dpi', 'auto') + $screenArgs

    Start-Process -FilePath $vcxsrvExe -ArgumentList $vcxsrvArgs -WindowStyle Hidden

    if (-not (Wait-ForXServer -Port $xPort -TimeoutSec 20)) {
        Write-Err2 "X Server nie odpowiedzial na porcie $xPort w ciagu 20s."
        Write-Err2 "Sprawdz, czy Zapora Windows nie blokuje VcXsrv (patrz Install-Prerequisites.ps1)."
        exit 1
    }
    Write-Ok "X Server dziala i nasluchuje na porcie $xPort."
}

# ---------------------------------------------------------------------------
# 5. Znajdz dystrybucje Ubuntu
# ---------------------------------------------------------------------------
Write-Step "Sprawdzam dystrybucje WSL..."
$distro = Get-UbuntuDistro -Pattern $DistroPattern
Write-Ok "Uzyta dystrybucja: $distro"

# ---------------------------------------------------------------------------
# 6. Sprawdz, czy sesja XFCE juz dziala (unikamy duplikatow)
# ---------------------------------------------------------------------------
Write-Step "Sprawdzam, czy sesja XFCE juz dziala w '$distro'..."
$existing = (& wsl.exe -d $distro -- bash -lc "pgrep -x xfce4-session" 2>$null) -join ''
$existing = $existing.Trim()

if ($existing) {
    Write-Ok "Sesja XFCE juz dziala (PID $existing). Nic wiecej nie trzeba robic."
    Write-Ok "Przelacz sie do okna VcXsrv, aby zobaczyc pulpit."
    exit 0
}

# ---------------------------------------------------------------------------
# 7. Sprawdz, czy skrypt startowy jest zainstalowany w WSL
# ---------------------------------------------------------------------------
$hasLauncher = (& wsl.exe -d $distro -- bash -lc "test -x ~/.local/bin/start-xfce-session.sh && echo yes" 2>$null) -join ''
if ($hasLauncher.Trim() -ne 'yes') {
    Write-Err2 "Nie znaleziono ~/.local/bin/start-xfce-session.sh w '$distro'."
    Write-Err2 "Uruchom najpierw jednorazowa konfiguracje: Install-Prerequisites.ps1"
    exit 1
}

# ---------------------------------------------------------------------------
# 8. Uruchom sesje XFCE w tle (odlaczona od tego procesu PowerShell)
# ---------------------------------------------------------------------------
Write-Step "Uruchamiam sesje XFCE w '$distro' (DISPLAY wykrywany dynamicznie w Linuksie)..."
& wsl.exe -d $distro -- bash -lc "XFCE_DISPLAY_NUM=$DisplayNum nohup ~/.local/bin/start-xfce-session.sh >/dev/null 2>&1 & disown; sleep 0.3" | Out-Null

# ---------------------------------------------------------------------------
# 9. Czekaj na start XFCE
# ---------------------------------------------------------------------------
$deadline = (Get-Date).AddSeconds(25)
$started = $false
while ((Get-Date) -lt $deadline) {
    $pid_ = (& wsl.exe -d $distro -- bash -lc "pgrep -x xfce4-session" 2>$null) -join ''
    if ($pid_.Trim()) { $started = $true; break }
    Start-Sleep -Milliseconds 700
}

if ($started) {
    Write-Ok "Pulpit XFCE gotowy! Przelacz sie do okna VcXsrv."
} else {
    Write-Err2 "XFCE nie wystartowalo w oczekiwanym czasie. Ostatnie logi:"
    & wsl.exe -d $distro -- bash -lc "tail -n 40 ~/.xfce-session.log 2>/dev/null"
    exit 1
}
