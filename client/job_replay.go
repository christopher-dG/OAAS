package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-vgo/robotgo"
	"github.com/mholt/archiver"
)

func InitReplayJob() error {
	xi, yi := robotgo.GetScreenSize()
	x, y := float64(xi), float64(yi)

	startReplayX = int(math.Round(x * replayScaleX))
	startReplayY = int(math.Round(y * replayScaleY))
	showGraphX = int(math.Round(x * graphScaleX))
	showGraphY = int(math.Round(y * graphScaleY))
	focusOsuX = int(math.Round(x * focusScaleX))
	focusOsuY = int(math.Round(y * focusScaleY))

	return nil
}

// ReplayJob is a replay recording/uploading job.
type ReplayJob struct {
	JobBase
	Beatmap struct {
		BeatmapsetID int `mapstructure:"beatmapset_id"`
	} `mapstructure:"beatmap"`
	Replay struct {
		ReplayData string  `mapstructure:"replay_data"` // Base64-encoded .osr file
		Length     float64 `mapstructure:"length"`      // Runtime in seconds
	} `mapstructure:"replay"`
	Skin struct {
		Name string `mapstructure:"name"`
		URL  string `mapstructure:"url"`
	} `mapstructure:"skin"`
}

// NewReplayJob creates a new replay job.
func NewReplayJob(b JobBase) ReplayJob {
	j := ReplayJob{}
	j.id = b.id
	j.logger = b.logger
	return j
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
	if err := j.record(); err != nil {
		return err
	}
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
	focusScaleX  = 0.1
	focusScaleY  = 0.5
)

var (
	// Pixel coordinates
	startReplayX int
	startReplayY int
	showGraphX   int
	showGraphY   int
	focusOsuX    int
	focusOsuY    int
)

// saveReplay saves the .osr replay file so that it can be imported.
func (j ReplayJob) saveReplay() error {
	path := filepath.Join(DirOsr, fmt.Sprintf("%d.osr", j.Id()))
	osr, err := base64.StdEncoding.DecodeString(j.Replay.ReplayData)
	if err != nil {
		return err
	}
	if err = ioutil.WriteFile(path, osr, 0644); err != nil {
		return err
	}
	return nil
}

// getBeatmap ensures that the right beatmap is downloaded to play the replay.
func (j ReplayJob) getBeatmap() error {
	files, err := ioutil.ReadDir(DirSongs)
	if err != nil {
		return err
	}
	for _, f := range files {
		if !f.IsDir() {
			continue
		}
		if strings.HasPrefix(f.Name(), fmt.Sprintf("%d ", j.Beatmap.BeatmapsetID)) {
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
		if err = j.downloadSkin(skinPath); err != nil {
			j.Logger().Println("Couldn't download skin (using current):", err)
			return nil
		}
	}

	var err error
	if Config.SimpleSkinLoading {
		err = j.loadSkinWithExec(skinPath)
	} else {
		err = j.loadSkinWithRestart(skinPath)
	}
	if err != nil {
		return err
	}

	return nil
}

// downloadSkin downloads the job's skin and saves it to dest.
func (j ReplayJob) downloadSkin(dest string) error {
	resp, err := http.Get(j.Skin.URL)
	if err != nil {
		return err
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("Bad status code: %d", resp.StatusCode)
	}

	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if err = ioutil.WriteFile(dest, b, 0644); err != nil {
		return err
	}

	return nil
}

// loadSkinsWithExec loads a skin the easy way by simply executing a .osk file.
// However it doesn't always work for some reason.
func (j ReplayJob) loadSkinWithExec(path string) error {
	// Copy the skin because executing it deletes it.
	b, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	dest := filepath.Base(path)
	if err = ioutil.WriteFile(dest, b, 0644); err != nil {
		return err
	}
	time.Sleep(time.Second * 5) // ???
	return StartOsu(dest)
}

// loadSkinWithRestart loads a skin the hard way by manually unzipping the skin,
// and manually reloading (either by shortcut key or restarting osu!).
func (j ReplayJob) loadSkinWithRestart(path string) error {
	dest := filepath.Join(DirSkins, strings.TrimSuffix(path, ".osk"))
	os.RemoveAll(dest)
	if err := archiver.DefaultZip.Unarchive(path, dest); err != nil {
		return err
	}

	if OsuIsRunning() {
		j.focusOsu()
		time.Sleep(time.Second)
		robotgo.KeyTap("S", "control", "alt", "shift") // TODO: Does this work?
	} else if err := StartOsu(); err != nil {
		return err
	}

	return nil
}

// focusOsu focuses the osu! window by clicking on it.
func (j ReplayJob) focusOsu() {
	robotgo.MoveMouse(focusOsuX, focusOsuY)
	for i := 0; i <= 10; i++ {
		robotgo.MouseClick()
		time.Sleep(time.Second / 10)
	}
}

// startRecording starts the replay recording.
func (j ReplayJob) startRecording() error {
	// Move to the replay button.
	robotgo.MoveMouse(startReplayX, startReplayY)

	// Start the recording.
	if err := StartRecording(); err != nil {
		return err
	}

	// Sit on the score screen for a bit.
	time.Sleep(time.Second * 5)

	// Start the replay.
	robotgo.MouseClick()

	go func() {
		// Skip any intro.
		for i := 0; i < 50; i++ {
			robotgo.KeyTap("space")
			time.Sleep(time.Second / 10)
		}
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
	j.focusOsu()

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
	time.Sleep(time.Second * 10)

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
