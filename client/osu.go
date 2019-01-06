package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"

	"github.com/mholt/archiver"
)

func InitOsu() error {
	fs, err := ioutil.ReadDir(DirOsuBase)
	if err != nil {
		return err
	}
	for _, f := range fs {
		if cfgRegex.MatchString(f.Name()) {
			osuCfg = filepath.Join(DirOsuBase, f.Name())
			break
		}
	}
	if osuCfg == "" {
		return errors.New("Couldn't find osu! config file")
	}

	b, err := ioutil.ReadFile(osuCfg)
	if err != nil {
		return err
	}
	if err = ioutil.WriteFile("osu!.user.cfg.bak", b, 0644); err != nil {
		return err
	}
	if err = ioutil.WriteFile(osuCfg, append(b, cfgEdits...), 0644); err != nil {
		return err
	}

	os.Mkdir(filepath.Join(DirSkins, scratchSkin), os.ModePerm)

	return nil
}

func CleanupOsu() {
	b, err := ioutil.ReadFile("osu!.user.cfg.bak")
	if err != nil {
		log.Println("Warning: no backup config file was found")
	} else if err = ioutil.WriteFile(osuCfg, b, 0644); err != nil {
		log.Println("Warning: restoring backup config file failed:", err)
	}
}

// DownloadSkin downloads a .osk skin and saves it to dest.
func DownloadSkin(url, dest string) error {
	resp, err := http.Get(url)
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

// LoadSkin prepares a skin to be reloaded with the osu! keyboard shortcut.
func LoadSkin(path string) error {
	dest := filepath.Join(DirSkins, scratchSkin)
	os.RemoveAll(dest)
	if err := archiver.DefaultZip.Unarchive(path, dest); err != nil {
		return err
	}

	return nil
}

const scratchSkin = "OAAS Scratch Skin"

var (
	osuCfg   string
	cfgRegex = regexp.MustCompile(`^osu!\..+\.cfg$`)
	cfgEdits = []byte(`

Username =
Password =
Fullscreen = 1
DimLevel = 100
FpsCounter =
FrameTimeDisplay =
IgnoreBeatmapSkins = 1
ShowReplayComments =
Skin = ` + scratchSkin + "\n")
)
