<#
.SYNOPSIS
    Jednorazowa konfiguracja: WSL2 + Ubuntu + XFCE + VcXsrv + skroty na Pulpicie.
    Uruchom ten skrypt RAZ. Jest bezpieczny do wielokrotnego uruchomienia -
    kazdy krok jest wykonywany tylko, jesli jeszcze nie zostal wykonany.

.NOTES
    Nie usuwa istniejacych dystrybucji WSL, nie kasuje danych uzytkownika.
    Wymaga uprawnien administratora dla: instalacji funkcji WSL, reguly Zapory,
    instalacji VcXsrv. Skrypt sam podnosi uprawnienia (UAC), jesli to potrzebne.
#>

[CmdletBinding()]
param(
    [string] $DistroName = 'Ubuntu'
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    [!]  $msg" -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "    [X]  $msg" -ForegroundColor Red }

# ===========================================================================
# 0. Podniesienie uprawnien (UAC) - wymagane dla Zapory / instalacji funkcji WSL
# ===========================================================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Ten skrypt wymaga uprawnien administratora - ponowne uruchomienie (UAC)..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($MyInvocation.MyCommand.Path)`""
    )
    exit
}

Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host " Konfiguracja: Windows -> WSL2 -> Ubuntu -> XFCE -> X" -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta

# ===========================================================================
# 1. Raport srodowiska (bez zadnych zalozen co do standardowych sciezek)
# ===========================================================================
Write-Step "Sprawdzam srodowisko..."

$winVer = (Get-CimInstance Win32_OperatingSystem).Caption
$winBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Ok "Windows: $winVer (build $winBuild)"

$desktopPath = [Environment]::GetFolderPath('Desktop')
$userProfile = $Env:USERPROFILE
Write-Ok "Profil uzytkownika: $userProfile"
Write-Ok "Pulpit: $desktopPath"

$wslgPresent = Test-Path "$Env:WINDIR\System32\wslg.exe" -PathType Leaf
if (-not $wslgPresent) { $wslgPresent = Test-Path "$Env:LOCALAPPDATA\Microsoft\WSL" }
Write-Ok "WSLg (zintegrowane GUI Microsoftu): $(if ($wslgPresent) {'wykryto skladniki'} else {'nie wykryto - nieistotne, uzywamy VcXsrv'})"

$wslInstalled = $null -ne (Get-Command wsl.exe -ErrorAction SilentlyContinue)
Write-Ok "wsl.exe dostepny: $wslInstalled"

# ===========================================================================
# 2. WSL2 - instalacja funkcji, jesli brak
# ===========================================================================
$needsReboot = $false

if (-not $wslInstalled) {
    Write-Step "WSL nie jest zainstalowany - instaluje (bez dystrybucji)..."
    & wsl.exe --install --no-distribution
    $needsReboot = $true
} else {
    Write-Step "Sprawdzam status WSL..."
    $statusRaw = (& wsl.exe --status 2>&1) -join "`n"
    Write-Host $statusRaw
    try { & wsl.exe --set-default-version 2 2>&1 | Out-Null } catch {}
}

if ($needsReboot) {
    Write-Warn2 "WSL zostal wlaczony po raz pierwszy. Wymagany jest RESTART komputera."
    Write-Warn2 "Po restarcie uruchom ten skrypt ponownie - kontynuuje automatycznie od tego miejsca."
    Read-Host "Wcisnij Enter, aby zakonczyc (pamietaj o restarcie)"
    exit
}

# ===========================================================================
# 3. Ubuntu - instalacja dystrybucji, jesli brak
# ===========================================================================
Write-Step "Sprawdzam zainstalowane dystrybucje WSL..."
$distros = (& wsl.exe -l -q 2>$null) | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ -ne '' }
Write-Ok ("Zainstalowane dystrybucje: " + ($(if ($distros) { $distros -join ', ' } else { '(brak)' })))

$ubuntu = $distros | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1

if (-not $ubuntu) {
    Write-Step "Ubuntu nie jest zainstalowane - instaluje ($DistroName)..."
    & wsl.exe --install -d $DistroName
    Write-Warn2 "Otworzy sie okno konsoli Ubuntu z prosba o ustawienie nazwy uzytkownika UNIX i hasla."
    Write-Warn2 "To jest jednorazowy, wymagany krok interaktywny - dokoncz go w tamtym oknie."
    Write-Host "Czekam, az konfiguracja konta zostanie zakonczona..." -ForegroundColor Yellow

    $deadline = (Get-Date).AddMinutes(10)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $whoami = (& wsl.exe -d $DistroName -- whoami 2>$null) -join ''
        if ($whoami.Trim()) { $ready = $true; break }
    }
    if (-not $ready) {
        Write-Err2 "Nie wykryto zakonczenia konfiguracji konta Ubuntu w ciagu 10 minut."
        Write-Err2 "Dokoncz konfiguracje w oknie Ubuntu, a potem uruchom ten skrypt ponownie."
        exit 1
    }
    $ubuntu = $DistroName
    Write-Ok "Konto Ubuntu skonfigurowane."
} else {
    Write-Ok "Znaleziono dystrybucje: $ubuntu"
}

$versionInfo = ((& wsl.exe -l -v 2>$null) -replace "`0", '') -join "`n"
if ($versionInfo -match "(?m)^\s*\*?\s*$([regex]::Escape($ubuntu))\s+\S+\s+1\s*$") {
    Write-Warn2 "$ubuntu dziala w WSL1 - konwertuje do WSL2 (dane zostaja zachowane)..."
    & wsl.exe --set-version $ubuntu 2
    Write-Ok "Konwersja do WSL2 zakonczona."
} else {
    Write-Ok "$ubuntu juz dziala w WSL2 (lub wersja zostanie ustawiona automatycznie)."
}

# ===========================================================================
# 4. VcXsrv - instalacja, jesli brak
# ===========================================================================
Write-Step "Sprawdzam VcXsrv..."
function Get-VcXsrvExe {
    $candidates = @(
        "$Env:ProgramFiles\VcXsrv\vcxsrv.exe",
        "${Env:ProgramFiles(x86)}\VcXsrv\vcxsrv.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command vcxsrv.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$vcxsrvExe = Get-VcXsrvExe
if (-not $vcxsrvExe) {
    Write-Step "VcXsrv nie jest zainstalowany - instaluje..."
    $installedViaWinget = $false
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        foreach ($pkgId in @('marha.VcXsrv', 'VcXsrv.VcXsrv')) {
            try {
                Write-Ok "Probuje winget install --id $pkgId ..."
                & winget.exe install --id $pkgId -e --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) { $installedViaWinget = $true; break }
            } catch {}
        }
    }

    if (-not $installedViaWinget) {
        Write-Warn2 "winget niedostepny lub nieudany - pobieram instalator z oficjalnego SourceForge (najnowsze wydanie)..."
        $installerPath = Join-Path $Env:TEMP 'vcxsrv-installer.exe'
        Invoke-WebRequest -Uri 'https://sourceforge.net/projects/vcxsrv/files/latest/download' `
            -OutFile $installerPath -UseBasicParsing
        if ((Get-Item $installerPath).Length -lt 1MB) {
            throw "Pobrany plik instalatora VcXsrv wyglada niepoprawnie (zbyt maly). Sprawdz polaczenie sieciowe."
        }
        Write-Ok "Instaluje VcXsrv (cicha instalacja)..."
        Start-Process -FilePath $installerPath -ArgumentList '/S' -Wait
    }

    $vcxsrvExe = Get-VcXsrvExe
    if (-not $vcxsrvExe) {
        throw "Instalacja VcXsrv nie powiodla sie - vcxsrv.exe nie zostal znaleziony po instalacji."
    }
    Write-Ok "VcXsrv zainstalowany: $vcxsrvExe"
} else {
    Write-Ok "VcXsrv juz zainstalowany: $vcxsrvExe"
}

# ===========================================================================
# 5. Regula Zapory Windows dla VcXsrv (polaczenia z WSL2)
# ===========================================================================
Write-Step "Konfiguruje Zapore Windows dla VcXsrv..."
$ruleName = 'VcXsrv (WSL2 X11)'
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existingRule) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Program $vcxsrvExe `
        -Action Allow -Profile Any -Protocol TCP | Out-Null
    Write-Ok "Regula Zapory dodana: $ruleName"
} else {
    Write-Ok "Regula Zapory juz istnieje: $ruleName"
}

# ===========================================================================
# 6. Instalacja XFCE i skryptu sesji wewnatrz Ubuntu
# ===========================================================================
Write-Step "Kopiuje skrypty do WSL i instaluje XFCE (to moze potrwac kilka minut)..."

$linuxDir = Join-Path $RepoRoot 'linux'
$setupScript = Join-Path $linuxDir 'setup-xfce.sh'
$launcherScript = Join-Path $linuxDir 'start-xfce-session.sh'

if (-not (Test-Path $setupScript) -or -not (Test-Path $launcherScript)) {
    throw "Nie znaleziono skryptow linux/setup-xfce.sh lub linux/start-xfce-session.sh w repozytorium."
}

# Skopiuj skrypty do domu uzytkownika w WSL przez stdin (konwersja CRLF->LF, dziala niezaleznie od dostepu do plikow Windows z WSL).
function Copy-ScriptIntoWsl {
    param([string]$LocalPath, [string]$RemoteName, [string]$Distro)
    $content = (Get-Content -Path $LocalPath -Raw) -replace "`r`n", "`n"
    $content | & wsl.exe -d $Distro -- bash -c "mkdir -p ~/.wslde-setup && cat > ~/.wslde-setup/$RemoteName && chmod +x ~/.wslde-setup/$RemoteName"
}

Copy-ScriptIntoWsl -LocalPath $setupScript -RemoteName 'setup-xfce.sh' -Distro $ubuntu
Copy-ScriptIntoWsl -LocalPath $launcherScript -RemoteName 'start-xfce-session.sh' -Distro $ubuntu

& wsl.exe -d $ubuntu -- bash -lc "bash ~/.wslde-setup/setup-xfce.sh"
if ($LASTEXITCODE -ne 0) {
    throw "Instalacja XFCE w Ubuntu nie powiodla sie (kod $LASTEXITCODE). Sprawdz komunikaty powyzej."
}
Write-Ok "XFCE zainstalowane w '$ubuntu'."

# ===========================================================================
# 7. Kopiowanie skryptow Start/Stop na Pulpit
# ===========================================================================
Write-Step "Kopiuje Start-Ubuntu-XFCE.ps1 / Stop-Ubuntu-XFCE.ps1 na Pulpit ($desktopPath)..."
Copy-Item -Path (Join-Path $ScriptDir 'Start-Ubuntu-XFCE.ps1') -Destination $desktopPath -Force
Copy-Item -Path (Join-Path $ScriptDir 'Stop-Ubuntu-XFCE.ps1') -Destination $desktopPath -Force
Write-Ok "Skopiowano."

# ===========================================================================
# 8. Skrot .lnk na Pulpicie (bez zmiany globalnej ExecutionPolicy)
# ===========================================================================
Write-Step "Tworze skrot 'Ubuntu XFCE.lnk' na Pulpicie..."
$shortcutPath = Join-Path $desktopPath 'Ubuntu XFCE.lnk'
$targetScript = Join-Path $desktopPath 'Start-Ubuntu-XFCE.ps1'

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$Env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`""
$shortcut.WorkingDirectory = $desktopPath
$shortcut.IconLocation = "$vcxsrvExe,0"
$shortcut.Description = 'Uruchamia pelny pulpit Ubuntu XFCE (VcXsrv + WSL2)'
$shortcut.Save()
Write-Ok "Skrot utworzony: $shortcutPath"

Write-Host "`n=====================================================" -ForegroundColor Magenta
Write-Host " Konfiguracja zakonczona! " -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "Kliknij dwukrotnie 'Ubuntu XFCE' na Pulpicie, aby uruchomic pelny pulpit XFCE." -ForegroundColor Green
