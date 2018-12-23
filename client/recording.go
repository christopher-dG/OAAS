package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/go-vgo/robotgo"
)

// Record records the video.
func (j Job) Record() error {
	osr := filepath.Join(replayDir, fmt.Sprintf("%d.osr", j.ID))
	if _, err := os.Stat(osr); err != nil {
		return err
	}

	log.Println("loading replay")
	if err := ExecOsu(osr); err != nil {
		return err
	}

	// Give some time for the replay to load.
	time.Sleep(time.Second * 5)

	log.Println("starting recording")
	if err := StartRecording(); err != nil {
		return err
	}

	// This isn't going to stop recording at the correct time,
	// it's only here as a backup in case something goes wrong.
	defer StopRecording()

	// Wait on the results screen for a bit.
	log.Println("waiting on score screen")
	time.Sleep(time.Second * 5)

	log.Println("starting replay")
	StartReplay()

	log.Println("waiting for map to end:", j.Replay.Length)
	time.Sleep(time.Second * time.Duration(j.Replay.Length))
	time.Sleep(time.Second * 2)

	log.Println("showing graph")
	ShowGraph()

	log.Println("waiting on graph")
	time.Sleep(time.Second * 5)

	log.Println("escaping")
	robotgo.KeyTap("escape")

	log.Println("waiting on score screen/leaderboard")
	time.Sleep(time.Second * 5)

	return StopRecording()
}
