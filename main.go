// Ubuntu-XFCE-Installer.exe
//
// Samodzielny instalator dla Windows: rozpakowuje osadzone skrypty
// (windows/*.ps1, linux/*.sh) do %LOCALAPPDATA%\WSLDE-XFCE i uruchamia
// windows/Install-Prerequisites.ps1, które konfiguruje WSL2 + Ubuntu +
// XFCE + VcXsrv oraz umieszcza skrypty startowe i skrot na Pulpicie.
package main

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

//go:embed windows linux
var payload embed.FS

func main() {
	fmt.Println("=====================================================")
	fmt.Println(" Ubuntu XFCE dla Windows - instalator")
	fmt.Println("=====================================================")

	if runtime.GOOS != "windows" {
		fmt.Println("Ten instalator dziala tylko na Windows.")
		os.Exit(1)
	}

	if !isElevated() {
		fmt.Println("Wymagane uprawnienia administratora - restart z UAC...")
		if err := relaunchElevated(); err != nil {
			fmt.Println("Nie udalo sie podniesc uprawnien:", err)
			pause()
			os.Exit(1)
		}
		fmt.Println("Otworzono nowe, podniesione okno - to okno mozna zamknac.")
		pause()
		return
	}

	installDir := filepath.Join(os.Getenv("LOCALAPPDATA"), "WSLDE-XFCE")
	fmt.Println("Rozpakowuje pliki do:", installDir)
	if err := extractPayload(installDir); err != nil {
		fmt.Println("Blad rozpakowywania plikow:", err)
		pause()
		os.Exit(1)
	}

	ps1 := filepath.Join(installDir, "windows", "Install-Prerequisites.ps1")
	fmt.Println("Uruchamiam konfiguracje:", ps1)
	fmt.Println("-----------------------------------------------------")
	cmd := exec.Command("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Dir = installDir
	runErr := cmd.Run()
	fmt.Println("-----------------------------------------------------")

	if runErr != nil {
		fmt.Println("Konfiguracja zakonczyla sie bledem:", runErr)
		fmt.Println("Sprawdz komunikaty powyzej - mozesz uruchomic ten plik ponownie, jest bezpieczny.")
		pause()
		os.Exit(1)
	}

	fmt.Println()
	fmt.Println("Gotowe! Na Pulpicie powinna pojawic sie ikona 'Ubuntu XFCE'.")
	fmt.Println("Kliknij ja dwukrotnie, aby uruchomic pelny pulpit Linuksa.")
	pause()
}

func pause() {
	fmt.Println("\nWcisnij Enter, aby zamknac to okno...")
	var s string
	fmt.Scanln(&s)
}

// extractPayload zapisuje osadzone pliki windows/ i linux/ na dysk,
// zachowujac wzgledna strukture katalogow wymagana przez Install-Prerequisites.ps1.
func extractPayload(dest string) error {
	roots := []string{"windows", "linux"}
	for _, root := range roots {
		err := fs.WalkDir(payload, root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			target := filepath.Join(dest, filepath.FromSlash(path))
			if d.IsDir() {
				return os.MkdirAll(target, 0o755)
			}
			data, err := payload.ReadFile(path)
			if err != nil {
				return err
			}
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				return err
			}
			return os.WriteFile(target, data, 0o755)
		})
		if err != nil {
			return err
		}
	}
	return nil
}
