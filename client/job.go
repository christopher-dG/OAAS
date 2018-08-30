package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/mholt/archiver"
)

const defaultSkin = "rf-default-skin"

var (
	skinsDir    = filepath.Join(config.OsuRoot, "Skins")
	beatmapsDir = filepath.Join(config.OsuRoot, "Songs")
	osuCfg      = filepath.Join(config.OsuRoot, fmt.Sprintf("osu.%s.cfg", username))
)

// Job is a recording/uploading job to be completed by the worker.
type Job struct {
	ID     int `json:"id"` // Job ID.
	Player struct {
		UserID   int    `json:"user_id"`  // Player ID.
		Username string `json:"username"` // Player name.
	} `json:"player"`
	Beatmap struct {
		BeatmapID    int    `json:"beatmap_id"`    // Beatmap ID.
		BeatmapsetID int    `json:"beatmapset_id"` // Mapset ID.
		Artist       string `json:"artist"`        // Song artist.
		Title        string `json:"title"`         // Song title.
		Version      string `json:"version"`       // Diff name.
		Mode         int    `json:"mode"`          // Game mode.
	} `json:"beatmap"` // Beatmap played.
	Replay string `json:"replay"` // Base64-encoded replay file.
	Skin   *struct {
		Name string `json:"name"` // Skin name.
		URL  string `json:"url"`  // Skin download URL.
	} `json:"skin"` // Skin to use (empty if default).
	Post *struct {
		ID     string `json:"id"`     // Post ID.
		Title  string `json:"title"`  // Post title.
		Author string `json:"author"` // Post author.
	} `json:"post"` // Reddit post that triggered the job (null if not applicable).
}

// Process processes the job from start to finish.
func (j Job) Process() {
	log.SetPrefix(fmt.Sprintf("[job %d] ", j.ID))
	log.Println("starting job")

	if err := j.Prepare(); err != nil {
		log.Println("job preparation failed:", err)
		return
	}
}

// Prepare downloads and installs all required assets.
func (j Job) Prepare() error {
	j.getSkin()
	return j.getBeatmap()
}

// getSkin downloads and installs the specified skin.
func (j Job) getSkin() {
	if j.Skin == nil {
		log.Println("no skin provided (using default)")
		setSkin(defaultSkin)
		return
	}

	skinPath := filepath.Join(skinsDir, j.Skin.Name)
	if f, err := os.Stat(skinPath); err == nil && f.IsDir() {
		log.Println("found existing skin")
		setSkin(j.Skin.Name)
		return
	}

	b, err := httpGet(j.Skin.URL)
	if err != nil {
		log.Println("couldn't download skin (using default):", err)
		setSkin(defaultSkin)
		return
	}

	zipPath := filepath.Join(os.TempDir(), j.Skin.Name+".zip")
	if err = ioutil.WriteFile(zipPath, b, 0644); err != nil {
		log.Println("saving skin failed (using default):", err)
		setSkin(defaultSkin)
		return
	}

	if err = archiver.Zip.Open(zipPath, skinPath); err != nil {
		log.Println("couldn't unzip skin (using default):", err)
		setSkin(defaultSkin)
		return
	}

	setSkin(j.Skin.Name)
}

// setSkin updates the user config file to install the skin.
func setSkin(name string) {
	log.Println("setting skin:", name)

	b, err := ioutil.ReadFile(osuCfg)
	if err != nil {
		log.Println("couldn't read config file:", err)
		return
	}

	skinLine := "Skin = " + name
	lines := strings.Split(string(b), "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "Skin =") {
			if line == skinLine {
				log.Println("skin is already set")
				return
			}
			lines[i] = "Skin = " + name
			break
		}
	}

	newCfg := []byte(strings.Join(lines, "\n"))
	if err := ioutil.WriteFile(osuCfg, newCfg, os.ModePerm); err != nil {
		log.Println("couldn't update config file:", err)
		return
	}

	log.Println("set skin to:", name)
}

// getBeatmap ensures that a mapset is downloaded.
func (j Job) getBeatmap() error {
	files, err := ioutil.ReadDir(beatmapsDir)
	if err != nil {
		return err
	}

	for _, f := range files {
		if !f.IsDir() {
			continue
		}

		if strings.HasPrefix(f.Name(), strconv.Itoa(j.Beatmap.BeatmapsetID)+" ") {
			log.Println("found existing mapset:", f.Name())
			return nil
		}
	}

	// TODO: Download the mapset.

	return errors.New("mapset not found")
}
