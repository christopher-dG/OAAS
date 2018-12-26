package main

import (
	"os/exec"
	"time"

	"github.com/go-vgo/robotgo"
)

// ExecOsu runs some osu! command (open replay, skin, etc.).
func ExecOsu(args ...string) error {
	return exec.Command(osuExe, args...).Start()
}

func StartReplay() {
	robotgo.MoveMouse(startReplayX, startReplayY)

	// Click multiple times just in case.
	for i := 0; i < 10; i++ {
		time.Sleep(time.Second / 10)
		robotgo.MouseClick()
	}

	// Press space bar a few times to skip the intro.
	go func() {
		for i := 0; i < 50; i++ {
			time.Sleep(time.Second / 10)
			robotgo.KeyTap("space")
		}
	}()
}

func ShowGraph() {
	robotgo.MoveMouse(showGraphX, showGraphY)
}
