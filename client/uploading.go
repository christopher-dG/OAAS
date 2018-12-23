package main

import (
	"errors"
	"io/ioutil"
	"log"
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

	log.Println("video path:", path)

	// TODO

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
		if strings.HasSuffix(f.Name(), obsFormat) {
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
