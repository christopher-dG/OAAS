package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"path/filepath"
	"strings"
	"time"
)

// Upload uploads the most recent video.
func (j Job) Upload() error {
	path, err := getNewestVideo()
	if err != nil {
		return err
	}

	// TODO: Delete me.
	log.Println("video path:", path)
	log.Println("video title:", j.makeTitle())

	return nil
}

// getNewestVideo gets the recording output folder from OBS and finds its newest video file.
func getNewestVideo() (string, error) {
	folder, err := GetRecordingFolder()
	if err != nil {
		return "", err
	}

	files, err := ioutil.ReadDir(folder)
	if err != nil {
		return "", err
	}

	var path string
	min := time.Hour
	for _, f := range files {
		if strings.HasPrefix(f.Name(), videoFormat) {
			if s := time.Since(f.ModTime()); s < min {
				min = s
				path = f.Name()
			}
		}
	}
	if path == "" {
		return "", errors.New("no new videos were found")
	}
	return filepath.Join(folder, path), nil
}

// makeTitle creates the title for the YouTube video.
func (j Job) makeTitle() string {
	s := fmt.Sprintf(
		"%s | %s - %s [%s]",
		j.Player.Username, j.Beatmap.Artist, j.Beatmap.Title, j.Beatmap.Version,
	)
	if m := combineMods(j.Score.Mods); m != "" {
		s += " " + m
	}
	s += fmt.Sprintf(" %.2f%%", j.Score.Accuracy)
	if j.Score.Combo == j.Beatmap.MaxCombo {
		s += " FC"
	} else if j.Score.NMiss > 0 {
		// We condition on there being at least one miss, because we don't
		// want to display it on scores where only sliderends were missed.
		s += fmt.Sprintf(" %d/%d", j.Score.Combo, j.Beatmap.MaxCombo)
	}
	s += fmt.Sprintf(" %dpp", int(math.Round(j.Score.PP)))
	return s
}

func combineMods(mods int) string {
	return ""
}
