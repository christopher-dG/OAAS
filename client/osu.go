package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/go-vgo/robotgo"
	"github.com/mholt/archiver"
)

func InitOsu() error {
	focusOsuX = int(math.Round(ScreenX * focusScaleX))
	focusOsuY = int(math.Round(ScreenY * focusScaleY))

	switch runtime.GOOS {
	case "windows":
		osuExe = "osu!.exe"
	default:
		osuExe = "osu!"
	}
	osuExe = filepath.Join(DirOsuBase, osuExe)

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
	if err = ioutil.WriteFile(osuCfg, osuCfgReplacements(b), 0644); err != nil {
		return err
	}

	if !Config.SimpleSkinLoading {
		os.Mkdir(filepath.Join(DirSkins, scratchSkin), os.ModePerm)
	}

	log.Println("===== Please move this window the the right side of your screen =====")
	if err = StartOsu(); err != nil {
		return err
	}
	time.Sleep(time.Second * 5)
	FocusOsu()

	return nil
}

func CleanupOsu() {
	StopOsu()
	b, err := ioutil.ReadFile("osu!.user.cfg.bak")
	if err != nil {
		log.Println("Warning: no backup config file was found")
	} else if err = ioutil.WriteFile(osuCfg, b, 0644); err != nil {
		log.Println("Warning: restoring backup config file failed:", err)
	}
}

// StartOsu starts osu! with the given arguments.
func StartOsu(args ...string) error {
	osuCmd = exec.Command(osuExe, args...)
	log.Println("Running command:", osuExe, strings.Join(args, " "))
	return osuCmd.Start()
}

// StopOsu stops the osu! process.
func StopOsu() error {
	if osuCmd.Process == nil {
		log.Println("osu! was not running")
		return nil
	}
	log.Println("Stopping osu! process")
	return osuCmd.Process.Kill()
}

// OsuIsRunning determines whether or not osu! is running.
func OsuIsRunning() bool {
	return osuCmd.ProcessState != nil && !osuCmd.ProcessState.Exited()
}

// FocusOsu focuses the osu! window by clicking on it.
func FocusOsu() {
	robotgo.MoveMouse(focusOsuX, focusOsuY)
	for i := 0; i <= 10; i++ {
		robotgo.MouseClick()
		time.Sleep(time.Second / 10)
	}
}

// HideScoreboard hides the scoreboard.
func HideScoreboard() error {
	b, err := ioutil.ReadFile(osuCfg)
	if err != nil {
		return err
	}
	if strings.Contains(string(b), "ScoreboardVisible = 1") {
		FocusOsu()
		robotgo.KeyTap("tab")
	}
	return nil
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

// LoadSkin loads a skin.
func LoadSkin(path string) error {
	if Config.SimpleSkinLoading {
		return loadSkinWithExec(path)
	} else {
		return loadSkinWithReplaceScratch(path)
	}
}

// loadSkinWithExec loads a skin by simply executing it.
func loadSkinWithExec(path string) error {
	return StartOsu(path)
}

// loadSkinWithReloadOrRestart loads a skin by replacing the current skin.
func loadSkinWithReplaceScratch(path string) error {
	dest := filepath.Join(DirSkins, scratchSkin)
	os.RemoveAll(dest)
	if err := archiver.DefaultZip.Unarchive(path, dest); err != nil {
		return err
	}

	if OsuIsRunning() {
		FocusOsu()
		time.Sleep(time.Second)
		robotgo.KeyTap("S", []string{"lctrl", "lalt", "lshift"}) // TODO: Make this work.
	} else {
		if err := StartOsu(); err != nil {
			return err
		}
		time.Sleep(time.Second * 5)
	}

	return nil
}

const (
	focusScaleX = 0.1
	focusScaleY = 0.5
)

var (
	osuExe string
	osuCfg string
	osuCmd *exec.Cmd

	focusOsuX int
	focusOsuY int

	cfgRegex    = regexp.MustCompile(`^osu!\..+\.cfg$`)
	scratchSkin = "OAAS Scratch Skin"
)

// osuCfgReplacements makes some option substitutions in the config file.
func osuCfgReplacements(content []byte) []byte {
	lines := strings.Split(string(content), "\r\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "Username =") {
			// Log out.
			log.Println("Setting Username =")
			lines[i] = "Username ="
		} else if strings.HasPrefix(line, "Password =") {
			// Log out.
			log.Println("Setting Passowrd =")
			lines[i] = "Password ="
		} else if strings.HasPrefix(line, "Fullscreen =") {
			// Make the window fullscreen.
			log.Println("Setting Fullscreen = 1")
			lines[i] = "Fullscreen = 1"
		} else if strings.HasPrefix(line, "DimLevel =") {
			// Dim background.
			log.Println("Setting DimLevel = 100")
			lines[i] = "DimLevel = 100"
		} else if strings.HasPrefix(line, "FpsCounter =") {
			// Don't show FPS.
			log.Println("Setting FpsCount = 0")
			lines[i] = "FpsCount = 0"
		} else if strings.HasPrefix(line, "FrameTimeDisplay =") {
			// Don't show frame time.
			log.Println("Setting FrameTimeDisplay = 0")
			lines[i] = "FrameTimeDisplay = 0"
		} else if strings.HasPrefix(line, "IgnoreBeatmapSkins =") {
			// Don't use beatmap skins.
			log.Println("Setting IgnoreBeatmapSkins = 1")
			lines[i] = "IgnoreBeatmapSkins = 1"
		} else if strings.HasPrefix(line, "ShowReplayComments =") {
			// Don't show replay commentary
			log.Println("Setting ShowReplayComments = 0")
			lines[i] = "ShowReplayComments = 0"
		} else if !Config.SimpleSkinLoading && strings.HasPrefix(line, "Skin =") {
			// Set scratch skin
			log.Println("Setting Skin = " + scratchSkin)
			lines[i] = "Skin = " + scratchSkin
		}
	}
	return []byte(strings.Join(lines, "\r\n"))
}
