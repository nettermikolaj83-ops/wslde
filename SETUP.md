# Konfiguracja i diagnostyka — Ubuntu XFCE na Windows (WSL2 + VcXsrv)

> **Najprościej:** pobierz `Ubuntu-XFCE-Installer.exe` z zakładki
> [Releases](../../releases/latest) i uruchom go — robi wszystko poniżej automatycznie.
> Ten dokument opisuje, co dzieje się „pod maską" i jak diagnozować problemy.

## 1. Jednorazowa konfiguracja (ze źródła, bez .exe)

1. Skopiuj cały folder repozytorium na dysk Windows, np. `C:\wslde` (foldery `windows\` i
   `linux\` muszą zostać razem — `Install-Prerequisites.ps1` odwołuje się do `..\linux\`).
2. Otwórz PowerShell (nie musi być jako administrator — skrypt sam poprosi o UAC gdy potrzeba)
   i uruchom:
   ```powershell
   cd C:\wslde
   .\windows\Install-Prerequisites.ps1
   ```
3. Skrypt wykonuje po kolei, **pomijając kroki już wykonane** (bezpieczny do wielokrotnego
   uruchamiania):
   - raport środowiska (wersja Windows, WSL, dystrybucje, VcXsrv, WSLg, ścieżki),
   - instalację funkcji WSL2, jeśli jej nie ma (⚠️ wymaga **restartu komputera** — jeśli
     skrypt o to poprosi, uruchom go ponownie po restarcie, kontynuuje automatycznie),
   - instalację Ubuntu, jeśli nie jest zainstalowane (⚠️ pierwsze uruchomienie Ubuntu wymaga
     **jednorazowego, interaktywnego** ustawienia nazwy użytkownika UNIX i hasła w osobnym
     oknie konsoli — dokończ ten krok, skrypt czeka i wykrywa zakończenie automatycznie),
   - konwersję do WSL2, jeśli dystrybucja była na WSL1 (bez utraty danych),
   - instalację VcXsrv (winget, a w razie niepowodzenia — pobranie oficjalnego instalatora
     z SourceForge),
   - regułę Zapory Windows dopuszczającą VcXsrv,
   - instalację XFCE i wszystkich zależności wewnątrz Ubuntu (⚠️ `apt` poprosi o **hasło
     sudo Twojego konta Ubuntu** wprost w tym samym oknie PowerShell — wpisz je, ekran nie
     pokazuje wpisywanych znaków, to normalne dla `sudo`),
   - skopiowanie `Start-Ubuntu-XFCE.ps1` / `Stop-Ubuntu-XFCE.ps1` na Twój Pulpit,
   - utworzenie skrótu **`Ubuntu XFCE.lnk`** na Pulpicie (uruchamia PowerShell z
     `-ExecutionPolicy Bypass` **tylko dla tego jednego skrótu** — nie zmienia globalnej
     polityki wykonywania skryptów w systemie).

## 2. Codzienne użycie

- **Start:** dwuklik na `Ubuntu XFCE` (Pulpit) albo `Start-Ubuntu-XFCE.ps1`.
- **Stop:** `Stop-Ubuntu-XFCE.ps1` (zamyka sesję XFCE; X Server zostaje włączony —
  dodaj `-StopXServer`, aby zamknąć też VcXsrv).
- Drugi dwuklik na `Start-Ubuntu-XFCE.ps1`, gdy sesja już działa, **nie tworzy duplikatu** —
  skrypt wykrywa działający `xfce4-session` i tylko informuje, że pulpit już jest gotowy.
- Po **restarcie Windows** X Server i sesja XFCE nie wznawiają się automatycznie (to zwykłe,
  bezpieczne zachowanie) — po restarcie po prostu kliknij `Ubuntu XFCE` jeszcze raz.

## 3. Jak to działa (kluczowe ustawienia)

- **X Server:** VcXsrv, tryb pełnoekranowy (`-fullscreen`), bez kontroli dostępu (`-ac` —
  konieczne, ponieważ WSL2 łączy się z innego adresu niż `127.0.0.1`), `-clipboard` (schowek
  Windows↔Linux), `-wgl` (akceleracja OpenGL). Użyj `Start-Ubuntu-XFCE.ps1 -Windowed`, jeśli
  wolisz duże okno (90% ekranu) zamiast pełnego ekranu.
- **Wykrywanie hosta Windows z WSL:** `linux/start-xfce-session.sh` sprawdza najpierw
  `ip route show default` (adres bramy = adres hosta Windows w WSL2), a w razie potrzeby
  `nameserver` z `/etc/resolv.conf` (o ile nie jest to lokalny stub `127.0.0.53`). Adres jest
  wykrywany **dynamicznie przy każdym starcie** — nigdy nie jest zapisany na sztywno, bo zmienia
  się między restartami WSL.
- **Zmienne środowiskowe w sesji Linuksa:** `DISPLAY=<host>:0`, `LIBGL_ALWAYS_INDIRECT=1`
  (kompatybilność OpenGL), `PULSE_SERVER=unix:/mnt/wslg/PulseServer` gdy WSLg jest dostępne
  (dźwięk „za darmo", bez dodatkowej instalacji).
  Jeśli chcesz akcelerację GPU dla konkretnej aplikacji, usuń `LIBGL_ALWAYS_INDIRECT` w
  `linux/start-xfce-session.sh` i uruchom `.\windows\Install-Prerequisites.ps1` ponownie (kopiuje
  zaktualizowany skrypt) — albo edytuj plik `~/.local/bin/start-xfce-session.sh` bezpośrednio w WSL.
- **Schowek:** `-clipboard` w VcXsrv (mostek CLIPBOARD Windows↔X) + `autocutsel` w sesji Linux
  (synchronizuje PRIMARY↔CLIPBOARD w X) — kopiowanie działa w obie strony.
- **Klawiatura:** VcXsrv odczytuje układ klawiatury Windows przy starcie X Servera — jeśli
  zmienisz układ Windows *po* starcie VcXsrv, zrestartuj X Server (`Stop-Ubuntu-XFCE.ps1
  -StopXServer`, potem `Start-Ubuntu-XFCE.ps1`). Ctrl+C/Ctrl+V, klawisze funkcyjne i Alt+Tab
  działają natywnie w oknie VcXsrv; globalny układ klawiatury Windows nie jest zmieniany.
- **Dystrybucja WSL:** wykrywana dynamicznie (`wsl -l -q`, wzorzec `Ubuntu*`) — nie jest
  zakładana nazwa na sztywno, obsłuży `Ubuntu`, `Ubuntu-22.04`, `Ubuntu-24.04` itd.

## 4. Test manualny po instalacji

Po `Install-Prerequisites.ps1`, w PowerShell:

```powershell
wsl -l -v                          # Ubuntu powinno mieć VERSION 2
Get-Process vcxsrv                 # po pierwszym Start-Ubuntu-XFCE.ps1
Test-NetConnection 127.0.0.1 -Port 6000
```

W WSL (`wsl -d Ubuntu`):

```bash
pgrep -x xfce4-session             # PID sesji XFCE
echo $DISPLAY                      # w terminalu XFCE, nie w tym z 'wsl -d'
cat ~/.xfce-session.log            # log startu / diagnostyka błędów
```

W samej sesji XFCE: otwórz Terminal (menu → Terminal Emulator) i Menedżer plików (Thunar),
sprawdź kopiowanie tekstu między Windows i oknem XFCE (Ctrl+C / Ctrl+V).

## 5. Rozwiązywanie problemów

| Problem | Rozwiązanie |
|---|---|
| X Server nie odpowiada na porcie 6000 | Sprawdź `Get-NetFirewallRule -DisplayName 'VcXsrv (WSL2 X11)'`; uruchom ponownie `Install-Prerequisites.ps1` jako admin, aby dodać regułę. |
| `DISPLAY` nie ustawia się / XFCE nie startuje | `cat ~/.xfce-session.log` w WSL — najczęściej brak trasy domyślnej (`ip route`) tuż po starcie WSL; poczekaj kilka sekund i kliknij `Start-Ubuntu-XFCE.ps1` ponownie. |
| Czarny ekran w oknie VcXsrv | To najczęściej `xfce4-session` wciąż się uruchamia — poczekaj chwilę, albo sprawdź log jak wyżej. |
| Brak dźwięku | Sprawdź `ls -la /mnt/wslg/PulseServer` w WSL — jeśli nie istnieje, Twoja wersja Windows/WSL nie ma WSLg; dźwięk wymaga wtedy dodatkowego serwera PulseAudio na Windows (poza zakresem automatycznej konfiguracji). |
| Ubuntu nie ma jeszcze konta użytkownika | Uruchom `wsl -d Ubuntu` recznie i dokończ tworzenie użytkownika, potem uruchom `Install-Prerequisites.ps1` ponownie. |
| Skrót `.lnk` nie działa po przeniesieniu repo | Skrót wskazuje na `Start-Ubuntu-XFCE.ps1` **na Pulpicie** (kopię, nie w repo) — uruchom ponownie `Install-Prerequisites.ps1`, aby odtworzyć skrót i kopię po przeniesieniu repozytorium. |

## 6. Bezpieczeństwo

- Żadny skrypt nie wykonuje `wsl --unregister`, nie usuwa katalogów użytkownika i nie
  nadpisuje istniejącej konfiguracji WSL bez potrzeby.
- Konwersja WSL1→WSL2 (jeśli wykryta) używa oficjalnej, nie-destrukcyjnej komendy
  `wsl --set-version` (dane zachowane).
- `ExecutionPolicy` nie jest zmieniana globalnie — skrót na Pulpicie używa
  `-ExecutionPolicy Bypass` tylko dla własnego, jednorazowego wywołania PowerShell.
