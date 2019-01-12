package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// MostRecentVideo finds the newest video file in the OBS output directory.
func MostRecentVideo() (string, error) {
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

// Upload uploads a video based on the configured uploader.
// If successful, it returns the URL of the uploaded video.
func Upload(path, title, description string, tags []string) (string, error) {
	switch Config.Uploader {
	case "youtube":
		return uploadYouTube(path, title, description, tags)
	case "":
		return "", errors.New("No uploader is configured")
	default:
		return "", errors.New("Unknown uploader " + Config.Uploader)
	}
}

var ytIdRegex = regexp.MustCompile("Upload successful! Video ID: (.*)")

// uploadYouTube uploads to YouTube.
func uploadYouTube(path, title, description string, tags []string) (string, error) {
	cmd := exec.Command(
		"youtube-uploader.exe",
		"-filename", path,
		"-categoryId", "20", // Gaming category.
		"-title", title,
		"-description", description,
		"-tags", strings.Join(tags, ","),
	)
	out, err := cmd.CombinedOutput()
	fmt.Println(string(out))
	if err != nil {
		return "", err
	}
	matches := ytIdRegex.FindSubmatch(out)
	if len(matches) == 0 {
		return "unknown", nil
	}
	return "https://youtu.be/" + string(matches[1]), nil
}
