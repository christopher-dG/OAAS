package main

import (
	"log"
	"os"
	"time"
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

	mapLength := time.Second * 10 // TODO: Get the length of the map.
	log.Println("waiting...")
	time.Sleep(time.Second) // Give some time to see the score screen.
	// StartReplay()
	time.Sleep(mapLength)

	// TODO: Press ESC to exit replay? We risk losing the score screen at that point.

	log.Println("moving to graph")
	ShowGraph()
	time.Sleep(time.Second * 3) // Give some time to see the graph.
	log.Println("stopping recording")
	if err := StopRecording(); err != nil {
		return err
	}

	// log.Println("quitting osu!")
	// if err := ExitOsu(); err != nil {
	// 	return err
	// }

	return nil
}
