package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-vgo/robotgo"
	"github.com/mitchellh/mapstructure"
)

func InitReplayJob() error {
	startReplayX = int(math.Round(ScreenX * replayScaleX))
	startReplayY = int(math.Round(ScreenY * replayScaleY))
	showGraphX = int(math.Round(ScreenX * graphScaleX))
	showGraphY = int(math.Round(ScreenY * graphScaleY))
	return nil
}

// ReplayJob is a replay recording/uploading job.
type ReplayJob struct {
	JobBase
	Beatmap struct {
		BeatmapsetId int `mapstructure:"beatmapset_id"`
	} `mapstructure:"beatmap"`
	Replay struct {
		Osr    string  `mapstructure:"osr"`    // Base64-encoded .osr file
		Length float64 `mapstructure:"length"` // Runtime in seconds
	} `mapstructure:"replay"`
	Skin struct {
		Name string `mapstructure:"name"`
		Url  string `mapstructure:"url"`
	} `mapstructure:"skin"`
}

// NewReplayJob creates a new replay job.
func NewReplayJob(b JobBase, data map[string]interface{}) (ReplayJob, error) {
	j := ReplayJob{}
	if err := mapstructure.Decode(data, &j); err != nil {
		return ReplayJob{}, err
	}
	j.id = b.id
	j.logger = b.logger
	return j, nil
}

// Prepare prepares the replay, beatmap, and skin.
func (j ReplayJob) Prepare() error {
	if err := j.saveReplay(); err != nil {
		return err
	}
	if err := j.getBeatmap(); err != nil {
		return err
	}
	if err := j.setupSkin(); err != nil {
		return err
	}
	return nil
}

// Execute records and uploads the replay.
func (j ReplayJob) Execute() error {
	UpdateStatus(j, StatusRecording, "")
	if err := j.record(); err != nil {
		return err
	}

	UpdateStatus(j, StatusUploading, "")
	if err := j.upload(); err != nil {
		return err
	}
	return nil
}

const (
	// Pixel ratios
	replayScaleX = 0.8546875
	replayScaleY = 0.7555555555555555
	graphScaleX  = 0.41354166666666664
	graphScaleY  = 0.8296296296296296
)

var (
	// Pixel coordinates
	startReplayX int
	startReplayY int
	showGraphX   int
	showGraphY   int
)

// saveReplay saves the .osr replay file so that it can be imported.
func (j ReplayJob) saveReplay() error {
	path := filepath.Join(DirOsr, fmt.Sprintf("%d.osr", j.Id()))
	osr, err := base64.StdEncoding.DecodeString(j.Replay.Osr)
	if err != nil {
		return err
	}
	j.Logger().Println("Saving replay to", path)
	if err = ioutil.WriteFile(path, osr, 0644); err != nil {
		return err
	}
	return nil
}

// getBeatmap ensures that the right beatmap is downloaded to play the replay.
func (j ReplayJob) getBeatmap() error {
	j.Logger().Println("Searching for beatmap", j.Beatmap.BeatmapsetId, "in", DirSongs)
	files, err := ioutil.ReadDir(DirSongs)
	if err != nil {
		return err
	}
	for _, f := range files {
		if f.IsDir() && strings.HasPrefix(f.Name(), fmt.Sprintf("%d ", j.Beatmap.BeatmapsetId)) {
			log.Println("Found existing mapset:", f.Name())
			return nil
		}
	}
	return errors.New("Mapset not found or downloaded")
}

// setupSkin installs the player's skin.
func (j ReplayJob) setupSkin() error {
	skinPath := filepath.Join(DirOsk, j.Skin.Name+".osk")
	if _, err := os.Stat(skinPath); os.IsNotExist(err) {
		j.Logger().Println("Downloading skin from:", j.Skin.Url)
		if err = DownloadSkin(j.Skin.Url, skinPath); err != nil {
			j.Logger().Println("Couldn't download skin (using current):", err)
			return nil
		}
	}
	j.Logger().Println("Loading skin:", skinPath)
	if err := LoadSkin(skinPath); err != nil {
		return err
	}
	return nil
}

// startRecording starts the replay recording.
func (j ReplayJob) startRecording() error {
	// Move to the replay button.
	robotgo.MoveMouse(startReplayX, startReplayY)

	// Start the recording.
	if err := StartRecording(); err != nil {
		return err
	}
	j.Logger().Println("Started recording")

	// Sit on the score screen for a bit.
	time.Sleep(time.Second * 5)

	// Start the replay.
	robotgo.MouseClick()
	j.Logger().Println("Started replay")

	go func() {
		// Skip any intro.
		for i := 0; i < 10; i++ {
			robotgo.KeyTap("space")
			time.Sleep(time.Second / 5)
		}
		HideScoreboard()
		// Move to the performance graph.
		robotgo.MoveMouse(showGraphX, showGraphY)
	}()

	return nil
}

// record records the replay.
func (j ReplayJob) record() error {
	// Check that the replay file exists.
	osr := filepath.Join(DirOsr, fmt.Sprintf("%d.osr", j.Id()))
	if _, err := os.Stat(osr); os.IsNotExist(err) {
		return err
	}

	// Load the replay.
	if err := StartOsu(osr); err != nil {
		return err
	}

	// Give it time to load.
	time.Sleep(time.Second * 5)

	// Ensure the focus is on the osu! window.
	FocusOsu()

	// This is just a safeguard.
	defer StopRecording()

	// Start recording.
	if err := j.startRecording(); err != nil {
		return err
	}

	// Wait for the replay to end.
	time.Sleep(time.Second * time.Duration(j.Replay.Length))

	// Move the the performance graph (this should already be done, but just in case).
	robotgo.MoveMouse(showGraphX, showGraphY)

	// Wait on the graph. Better to wait too long than too short.
	time.Sleep(time.Second * 20)

	// Stop the recording.
	if err := StopRecording(); err != nil {
		return err
	}

	return nil
}

// upload uploads a newly recorded video.
func (j ReplayJob) upload() error {
	return nil
}
