package main

import (
	"log"
	"os"
	"time"

	"github.com/go-vgo/robotgo"
)

// Record records the video.
func (j Job) Record() error {
	osr := j.replayPath()
	if _, err := os.Stat(osr); err != nil {
		return err
	}

	// log.Println("starting osu!")
	// if err := StartOsu(osr); err != nil {
	// 	return err
	// }

	// Give some time for osu! to start.
	time.Sleep(time.Second * 10)

	log.Println("setting scene")
	if err := SetScene(); err != nil {
		return err
	}

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
	StartReplay()
	// Wait for the map to end.
	log.Println("waiting for map to end:", j.Beatmap.TotalLength)
	time.Sleep(time.Second * time.Duration(j.Beatmap.TotalLength))
	// Small buffer for map ending.
	log.Println("waiting buffer")
	time.Sleep(time.Second * 2)
	// Move the cursor to the graph.
	log.Println("showing graph")
	ShowGraph()
	// Stay on the graph for some time.
	log.Println("waiting on graph")
	time.Sleep(time.Second * 5)
	// Press escape to either quit a map's outro or go back to the leaderboard.
	// Either case is fine.
	log.Println("pressing esc")
	robotgo.KeyTap("escape")
	log.Println("waiting on score screen/leaderboard")
	time.Sleep(time.Second * 5)

	if err := StopRecording(); err != nil {
		return err
	}

	// log.Println("quitting osu!")
	// if err := ExitOsu(); err != nil {
	// 	return err
	// }

	return nil
}
