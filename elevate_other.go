//go:build !windows

package main

import "fmt"

func isElevated() bool { return true }

func relaunchElevated() error {
	return fmt.Errorf("elevation nie jest wspierana na tej platformie")
}
