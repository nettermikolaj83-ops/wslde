<#
.SYNOPSIS
    Bezpiecznie zamyka sesje XFCE w WSL2 oraz (opcjonalnie) X Server (VcXsrv).

.PARAMETER StopXServer
    Dodatkowo zamknij VcXsrv. Domyslnie X Server jest pozostawiany dzialajacy
    (na wypadek gdyby korzystaly z niego inne aplikacje).
#>

[CmdletBinding()]
param(
    [string] $DistroPattern = 'Ubuntu*',
    [switch] $StopXServer
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }

function Get-UbuntuDistro {
    param([string]$Pattern)
    $names = & wsl.exe -l -q 2>$null |
        ForEach-Object { ($_ -replace "`0", '').Trim() } |
        Where-Object { $_ -ne '' }
    return ($names | Where-Object { $_ -like $Pattern } | Select-Object -First 1)
}

$distro = Get-UbuntuDistro -Pattern $DistroPattern
if ($distro) {
    Write-Step "Zamykam sesje XFCE w '$distro'..."
    & wsl.exe -d $distro -- bash -lc "pkill -x xfce4-session; pkill -f 'dbus-launch --exit-with-session startxfce4'" | Out-Null
    Write-Ok "Zadanie zamkniecia wyslane."
} else {
    Write-Ok "Nie znaleziono dystrybucji '$DistroPattern' - pomijam."
}

if ($StopXServer) {
    Write-Step "Zamykam X Server (VcXsrv)..."
    Get-Process -Name 'vcxsrv' -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Ok "VcXsrv zamkniety."
} else {
    Write-Ok "X Server pozostaje wlaczony (uzyj -StopXServer aby go rowniez zamknac)."
}
