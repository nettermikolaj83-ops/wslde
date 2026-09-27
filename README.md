# wslde — pełny pulpit Ubuntu XFCE na Windows przez WSL2

Kompletne środowisko graficzne Linuksa na Windows:

```
Windows → WSL2 → Ubuntu → XFCE → VcXsrv (zewnętrzny X Server)
```

Efekt końcowy: dwuklik na **`Ubuntu XFCE.lnk`** na Pulpicie → uruchamia się X Server,
Ubuntu, wszystkie zmienne środowiskowe, a następnie pełna sesja XFCE (panel, menu,
menedżer plików, terminal, okna) — bez wpisywania żadnej komendy.

## Zawartość repozytorium

| Plik | Rola |
|---|---|
| `windows/Install-Prerequisites.ps1` | **Uruchamiane raz.** Sprawdza środowisko, instaluje WSL2/Ubuntu/VcXsrv/XFCE, tworzy skróty na Pulpicie. |
| `windows/Start-Ubuntu-XFCE.ps1` | Codzienny start. Samodzielny plik kopiowany na Pulpit — to właśnie ten plik odpalany jest dwuklikiem. |
| `windows/Stop-Ubuntu-XFCE.ps1` | Bezpieczne zamknięcie sesji XFCE (opcjonalnie też X Servera). |
| `linux/setup-xfce.sh` | Instaluje XFCE i zależności wewnątrz Ubuntu (wywoływane automatycznie przez `Install-Prerequisites.ps1`). |
| `linux/start-xfce-session.sh` | Skrypt startowy sesji XFCE w WSL — dynamicznie wykrywa IP hosta Windows, ustawia `DISPLAY` i startuje `startxfce4`. |
| `SETUP.md` | Instrukcja jednorazowej konfiguracji i rozwiązywanie problemów. |

## Szybki start

1. Sklonuj/skopiuj to repozytorium na dysk Windows (np. `C:\wslde`), zachowując strukturę folderów `windows/` i `linux/` razem.
2. Otwórz PowerShell w folderze repo i uruchom:
   ```powershell
   .\windows\Install-Prerequisites.ps1
   ```
   Skrypt sam podniesie uprawnienia (UAC), doinstaluje brakujące elementy i skopiuje
   `Start-Ubuntu-XFCE.ps1` / `Stop-Ubuntu-XFCE.ps1` oraz skrót `Ubuntu XFCE.lnk` na Twój Pulpit.
3. Od tej pory: dwuklik na **`Ubuntu XFCE`** na Pulpicie = pełny pulpit Linuksa.

Zobacz `SETUP.md` po szczegóły, wymagane kroki interaktywne (restart / pierwsze logowanie
Ubuntu) i diagnostykę.

> **Uwaga dot. tej konfiguracji:** te skrypty zostały przygotowane i sprawdzone statycznie
> (składnia, logika), ale nie zostały wykonane na żywym Windows/WSL2 w tej sesji — to
> środowisko to izolowany kontener Linux w chmurze, bez dostępu do Twojego komputera.
> Uruchom `Install-Prerequisites.ps1` i zgłoś dowolny błąd — poprawię go od razu.
