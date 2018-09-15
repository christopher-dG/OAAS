package main

import (
	"os"
	"time"
)

// Record records the video.
func (j Job) Record() error {
	osr := j.replayPath()
	if _, err := os.Stat(osr); err != nil {
		return err
	}

	if err := StartOsu(osr); err != nil {
		return err
	}

	// Give some time for osu! to start.
	time.Sleep(time.Second * 10)

	if err := StartRecording(); err != nil {
		return err
	}

	// This isn't going to stop recording at the correct time,
	// it's only here as a backup in case something goes wrong.
	defer StopRecording()

	mapLength := time.Second // TODO: Get the length of the map.
	time.Sleep(time.Second)  // Give some time to see the score screen.
	StartReplay()
	time.Sleep(mapLength)

	// TODO: Press ESC to exit replay? We risk losing the score screen at that point.

	ShowGraph()
	time.Sleep(time.Second * 3) // Give some time to see the graph.
	if err := StopRecording(); err != nil {
		return err
	}

	if err := ExitOsu(); err != nil {
		return err
	}

	return nil
}
