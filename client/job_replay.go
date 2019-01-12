package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/mitchellh/mapstructure"
)

// ReplayJob is a replay recording/uploading job.
type ReplayJob struct {
	JobBase
	Beatmap struct {
		BeatmapsetId int `mapstructure:"beatmapset_id"`
	} `mapstructure:"beatmap"`
	Replay struct {
		Osr    string `mapstructure:"osr"`    // Base64-encoded .osr file
		Length int    `mapstructure:"length"` // Runtime in seconds
	} `mapstructure:"replay"`
	Skin struct {
		Name string `mapstructure:"name"`
		Url  string `mapstructure:"url"`
	} `mapstructure:"skin"`
	YouTube struct {
		Title       string   `mapstructure:"title"`
		Description string   `mapstructure:"description"`
		Tags        []string `mapstructure:"tags"`
	}
	runtime struct {
		Osk string // Path to the skin on disk
		Osr string // Path to the replay on disk
		Mp4 string // Path to the recorded video file on disk.
	}
}

// NewReplayJob creates a new replay job.
func NewReplayJob(b JobBase, data map[string]interface{}) (*ReplayJob, error) {
	j := ReplayJob{}
	if err := mapstructure.Decode(data, &j); err != nil {
		return nil, err
	}
	j.id = b.id
	j.logger = b.logger
	return &j, nil
}

// Prepare prepares the replay, beatmap, and skin.
func (j *ReplayJob) Prepare() error {
	if err := j.saveReplay(); err != nil {
		return err
	}
	if err := j.getBeatmap(); err != nil {
		return err
	}
	if err := j.downloadSkin(); err != nil {
		return err
	}
	return nil
}

// Execute records and uploads the replay.
func (j *ReplayJob) Execute() error {
	UpdateStatus(j, StatusRecording, "")
	if err := exec.Command(
		"record-replay.exe",
		j.runtime.Osk,
		j.runtime.Osr,
		strconv.Itoa(j.Replay.Length),
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
func (j *ReplayJob) saveReplay() error {
	path := filepath.Join(DirOsr, fmt.Sprintf("%d.osr", j.Id()))
	osr, err := base64.StdEncoding.DecodeString(j.Replay.Osr)
	if err != nil {
		return err
	}
	j.Logger().Println("Saving replay to", path)
	if err = ioutil.WriteFile(path, osr, 0644); err != nil {
		return err
	}
	j.runtime.Osr = path
	return nil
}

// getBeatmap ensures that the right beatmap is downloaded to play the replay.
func (j *ReplayJob) getBeatmap() error {
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

// downloadSkin downloads the player's skin.
func (j *ReplayJob) downloadSkin() error {
	skinPath := filepath.Join(DirOsk, j.Skin.Name+".osk")
	if _, err := os.Stat(skinPath); os.IsNotExist(err) {
		j.Logger().Println("Downloading skin from:", j.Skin.Url)
		if err = DownloadSkin(j.Skin.Url, skinPath); err != nil {
			j.Logger().Println("Couldn't download skin (using current):", err)
			return nil
		}
	}
	j.runtime.Osk = skinPath
	return nil
}

// upload uploads a newly recorded video.
func (j *ReplayJob) upload() error {
	mp4, err := j.mostRecentVideo()
	if err != nil {
		return err
	}
	j.runtime.Mp4 = mp4
	switch Config.Uploader {
	case "youtube":
		return j.uploadYouTube()
	default:
		return errors.New("No uploader is configured")
	}
}

// uploadYouTube uploads a video to YouTube.
func (j *ReplayJob) uploadYouTube() error {
	cmd := exec.Command(
		"youtube-uploader.exe",
		"-filename", j.runtime.Mp4,
		"-categoryId", "20", // Gaming category.
		"-title", j.YouTube.Title,
		"-description", j.YouTube.Description,
		"-tags", strings.Join(j.YouTube.Tags, ","),
	)
	b, err := cmd.CombinedOutput()
	fmt.Println(string(b))
	return err
}

// mostRecentVideo finds the newest video file in the OBS output directory.
func (j *ReplayJob) mostRecentVideo() (string, error) {
	fs, err := ioutil.ReadDir(Config.ObsOutDir)
	if err != nil {
		return "", err
	}
	fn := ""
	newest := time.Time{}
	for _, f := range fs {
		if strings.HasSuffix(f.Name(), ".mp4") && !f.IsDir() && f.ModTime().After(newest) {
			fn = f.Name()
			newest = f.ModTime()
		}
	}
	if fn == "" {
		return "", errors.New("Didn't find any video files")
	}
	if time.Since(newest) > time.Minute {
		return "", errors.New("A video file was found, but it was too old")
	}
	return filepath.Join(Config.ObsOutDir, fn), nil
}
