package main

import (
	"errors"
	"math"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"

	"github.com/go-vgo/robotgo"
)

const (
	replayScaleX = 0.8546875
	replayScaleY = 0.7555555555555555
	graphScaleX  = 0.41354166666666664
	graphScaleY  = 0.8296296296296296
)

var (
	ErrOsuNotRunning     = errors.New("osu! is not running")
	ErrOsuAlreadyRunning = errors.New("osu! is already running")

	osuCmd *exec.Cmd

	osuExe = func() string {
		if runtime.GOOS == "windows" {
			return "osu!.exe"
		}
		return "osu!"
	}()

	sizeX, sizeY = func() (float64, float64) {
		x, y := robotgo.GetScreenSize()
		return float64(x), float64(y)
	}()
)

// StartOsu opens osu!.
func StartOsu(args ...string) error {
	// TODO: Is using the ProcessState in this way correct?
	if osuCmd != nil && osuCmd.ProcessState != nil && !osuCmd.ProcessState.Exited() {
		return ErrOsuAlreadyRunning
	}

	osuCmd = exec.Command(filepath.Join(config.OsuRoot, osuExe), args...)
	return osuCmd.Start()
}

// ExitOsu exits osu!. It depends on the window being active.
func ExitOsu() error {
	// TODO: Is using the ProcessState in this way correct?
	if osuCmd == nil || osuCmd.ProcessState == nil || osuCmd.ProcessState.Exited() {
		return ErrOsuNotRunning
	}

	return osuCmd.Process.Kill()
}

func StartReplay() {
	robotgo.MoveMouse(int(math.Round(sizeX*replayScaleX)), int(math.Round(sizeY*replayScaleY)))
	robotgo.MouseClick()
	// Press space bar a few times to skip the intro.
	go func() {
		for i := 0; i < 5; i++ {
			time.Sleep(time.Second)
			robotgo.KeyTap("space")
		}
	}()
}

func ShowGraph() {
	robotgo.MoveMouse(int(math.Round(sizeX*graphScaleX)), int(math.Round(sizeY*graphScaleY)))
}
