//go:build windows

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"unsafe"
)

// isElevated wykrywa uprawnienia administratora bez zaleznosci zewnetrznych:
// dostep do surowego dysku fizycznego wymaga podniesionego procesu.
func isElevated() bool {
	f, err := os.Open(`\\.\PHYSICALDRIVE0`)
	if err != nil {
		return false
	}
	f.Close()
	return true
}

// relaunchElevated ponownie uruchamia ten sam plik .exe z UAC (verb "runas").
func relaunchElevated() error {
	exePath, err := os.Executable()
	if err != nil {
		return err
	}
	dir := filepath.Dir(exePath)

	shell32 := syscall.NewLazyDLL("shell32.dll")
	shellExecute := shell32.NewProc("ShellExecuteW")

	verbPtr, err := syscall.UTF16PtrFromString("runas")
	if err != nil {
		return err
	}
	exePtr, err := syscall.UTF16PtrFromString(exePath)
	if err != nil {
		return err
	}
	dirPtr, err := syscall.UTF16PtrFromString(dir)
	if err != nil {
		return err
	}

	const swShowNormal = 1
	ret, _, _ := shellExecute.Call(
		0,
		uintptr(unsafe.Pointer(verbPtr)),
		uintptr(unsafe.Pointer(exePtr)),
		0,
		uintptr(unsafe.Pointer(dirPtr)),
		swShowNormal,
	)
	if ret <= 32 {
		return fmt.Errorf("ShellExecute zwrocil kod %d", ret)
	}
	return nil
}
