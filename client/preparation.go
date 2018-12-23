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
)

// Prepare downloads and installs all required assets.
func (j Job) Prepare() error {
	if err := saveReplay(j); err != nil {
		return err
	}
	if err := getBeatmap(j); err != nil {
		return err
	}
	setupSkin(j)
	return nil
}

// setupSkin downloads and installs the specified skin.
func setupSkin(j Job) {
	if j.Skin == nil {
		log.Println("no skin provided (using default)")
		loadSkin(defaultSkin)
		return
	}

	skinPath := filepath.Join(skinDir, j.Skin.Name+".osk")
	if _, err := os.Stat(skinPath); err != nil {
		// Download the skin.
		b, err := httpGetBody(j.Skin.URL)
		if err != nil {
			log.Println("couldn't download skin (using default):", err)
			loadSkin(defaultSkin)
			return
		}

		if err = ioutil.WriteFile(skinPath, b, 0644); err != nil {
			log.Println("saving skin failed (using default):", err)
			loadSkin(defaultSkin)
			return
		}
	}

	loadSkin(j.Skin.Name)
}

func loadSkin(skin string) {
	skinPath := filepath.Join(skinDir, skin+".osk")
	if _, err := os.Stat(skinPath); err != nil {
		log.Println("skin does not exist:", skinPath)
		return
	}

	// Copy the skin (loading it is destructive).
	b, err := ioutil.ReadFile(skinPath)
	if err != nil {
		log.Println("copying skin failed (read):", err)
		ExecOsu(skinPath)
		return
	}
	if err := ioutil.WriteFile(skin+".osk", b, 0644); err != nil {
		log.Println("copying skin failed (write):", err)
		ExecOsu(skinPath)
		return
	}

	log.Println("loading skin:", skin)
	ExecOsu(skin + ".osk")
}

// getBeatmap ensures that a mapset is downloaded.
func getBeatmap(j Job) error {
	files, err := ioutil.ReadDir(beatmapDir)
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

	// TODO: Download the mapset, need some magic for this.
	// Maybe the server could upload to S3 and give a presigned URL,
	// but that would be redundant most of the time.

	return errors.New("mapset not found or downloaded")
}

// saveReplay decodes the job's replay file and saves it.
func saveReplay(j Job) error {
	path := filepath.Join(replayDir, fmt.Sprintf("%d.osr", j.ID))
	if _, err := os.Stat(path); err == nil { // Replay file already exists.
		return nil
	}

	osr, err := base64.StdEncoding.DecodeString(j.Replay.Data)
	if err != nil {
		return err
	}

	if err = ioutil.WriteFile(path, osr, 0644); err != nil {
		return err
	}

	return nil
}
