package main

import (
	"errors"
	"io/ioutil"
	"log"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

func InitOsu() error {
	switch runtime.GOOS {
	case "windows":
		osuExe = "osu!.exe"
	default:
		osuExe = "osu!"
	}
	cwd, err := filepath.Abs(".")
	if err != nil {
		return err
	}
	osuRoot = filepath.Dir(cwd)
	osuExe = filepath.Join(osuRoot, osuExe)

	fs, err := ioutil.ReadDir(osuRoot)
	if err != nil {
		return err
	}
	for _, f := range fs {
		if cfgRegex.MatchString(f.Name()) {
			osuCfg = f.Name()
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
	if err = ioutil.WriteFile(osuCfg+".bak", b, 0644); err != nil {
		return err
	}

	found := false
	write := false
	if !Config.SimpleSkinLoading {
		lines := strings.Split(string(b), "\n")
		for i, line := range lines {
			if strings.HasPrefix(line, "Skin = ") {
				found = true
				if lines[i] != "Skin = "+scratchSkin {
					write = true
					lines[i] = "Skin = " + scratchSkin
				}
				break
			}
		}
		if !found {
			return errors.New("Couldn't find skin entry in config file")
		}
		if write {
			b := []byte(strings.Join(lines, "\n"))
			if err := ioutil.WriteFile(osuCfg, b, 0644); err != nil {
				return err
			}
		}
	}

	return nil
}

func CleanupOsu() {
	StopOsu()
	b, err := ioutil.ReadFile(osuCfg + ".bak")
	if err != nil {
		log.Println("Warning: no backup config file was found")
	} else if err = ioutil.WriteFile(osuCfg, b, 0644); err != nil {
		log.Println("Warning: restoring backup config file failed:", err)
	}
}

// StartOsu starts osu! with the given arguments.
func StartOsu(args ...string) error {
	osuCmd = exec.Command(osuExe, args...)
	return osuCmd.Start()
}

// StopOsu stops the osu! process.
func StopOsu() error {
	if osuCmd.Process != nil {
		return osuCmd.Process.Kill()
	}
	return nil
}

var (
	osuRoot string
	osuExe  string
	osuCfg  string
	osuCmd  *exec.Cmd

	cfgRegex    = regexp.MustCompile(`^osu\..+\.cfg$`)
	scratchSkin = "OAAS Scratch Skin"
)

// OsuIsRunning determines whether or not osu! is running.
func OsuIsRunning() bool {
	return osuCmd.ProcessState != nil && !osuCmd.ProcessState.Exited()
}
