package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/mitchellh/mapstructure"
)

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
	if err := exec.Command(
		"record-replay.exe",
		filepath.Join(DirOsr, fmt.Sprintf("%d.osr", j.Id())),
		strconv.Itoa(int(math.Round(j.Replay.Length))),
	).Run(); err != nil {
		return err
	}

	UpdateStatus(j, StatusUploading, "")
	if err := j.upload(); err != nil {
		return err
	}
	return nil
}

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

// upload uploads a newly recorded video.
func (j ReplayJob) upload() error {
	return nil
}
