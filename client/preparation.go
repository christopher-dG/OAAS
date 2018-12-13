package main

import (
	"encoding/base64"
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

const defaultSkin = "rf-default-skin" // osu! skin to use when none is provided.

var (
	skinsDir    = filepath.Join(config.OsuRoot, "Skins")
	beatmapsDir = filepath.Join(config.OsuRoot, "Songs")
	osuCfg      = filepath.Join(config.OsuRoot, fmt.Sprintf("osu.%s.cfg", username))
)

// Prepare downloads and installs all required assets.
func (j Job) Prepare() error {
	j.setupSkin()
	if err := j.saveReplay(); err != nil {
		return err
	}
	return j.getBeatmap()
}

// setupSkin downloads and installs the specified skin.
func (j Job) setupSkin() {
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

	b, err := getBody(j.Skin.URL)
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

		if strings.HasPrefix(f.Name(), strconv.Itoa(j.BeatmapsetID)+" ") {
			log.Println("found existing mapset:", f.Name())
			return nil
		}
	}

	// TODO: Download the mapset, need some magic for this.
	// Maybe the server could upload to S3 and give a presigned URL,
	// but that would be redundant most of the time.

	return errors.New("mapset not found or downloaded")
}

// saveReplay decodes the job's replay file and saves it.
func (j Job) saveReplay() error {
	path := j.replayPath()

	if _, err := os.Stat(path); err == nil { // Replay file already exists.
		return nil
	}

	osr, err := base64.StdEncoding.DecodeString(j.Replay)
	if err != nil {
		return err
	}

	if err = ioutil.WriteFile(path, osr, 0644); err != nil {
		return err
	}

	return nil
}
