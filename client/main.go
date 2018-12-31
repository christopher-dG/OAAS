package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"os/user"
	"path/filepath"

	yaml "gopkg.in/yaml.v2"
)

var (
	// Logging
	LogWriter io.Writer

	// State
	Busy = false
	Jobs = make(chan Job)

	// Configuration
	Config = struct {
		ApiUrl            string `yaml:"api_url"`
		ApiKey            string `yaml:"api_key"`
		ObsPort           int    `yaml:"obs_port"`
		ObsPassword       string `yaml:"obs_password"`
		SimpleSkinLoading bool   `yaml:"simple_skin_loading"`
	}{}

	// ID
	WorkerId string

	// Dirs
	DirOsk   string // Skin zips
	DirOsr   string // Replays
	DirSkins string // Skin directories
	DirSongs string // Map directories
)

func init() {
	// Global: logging
	file, err := os.OpenFile("log.txt", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal("Couldn't open log file:", err)
	}
	LogWriter = io.MultiWriter(os.Stdout, file)
	log.SetOutput(LogWriter)

	// Global: configuration
	b, err := ioutil.ReadFile("config.yml")
	if err != nil {
		log.Fatal("Couldn't read config file:", err)
	}
	if err = yaml.Unmarshal(b, &Config); err != nil {
		log.Fatal("Couldn't parse config file:", err)
	}
	if Config.ObsPort == 0 {
		Config.ObsPort = 4444 // Default port.
	}

	// Global: ID
	if b, err = ioutil.ReadFile("id.txt"); err == nil {
		WorkerId = string(b)
	} else {
		i := rand.Int31n(9999999)
		usr, err := user.Current()
		if err != nil {
			log.Fatal("Couldn't get current user:", err)
		}
		WorkerId = fmt.Sprintf("%s-%d", usr.Username, i)
		ioutil.WriteFile("id.txt", []byte(WorkerId), 0644)
	}

	// Global: Dirs
	cwd, err := filepath.Abs(".")
	if err != nil {
		log.Fatal("Couldn't get current folder:", err)
	}
	DirOsk = filepath.Join(cwd, "osk")
	DirOsr = filepath.Join(cwd, "osr")
	DirSkins = filepath.Join(filepath.Dir(cwd), "Skins")
	DirSongs = filepath.Join(filepath.Dir(cwd), "Songs")

	// Per-module initialization
	if err := InitObs(); err != nil {
		log.Fatal("OBS initialization failed:", err)
	}
	if err := InitOsu(); err != nil {
		log.Fatal("osu! initialization failed:", err)
	}
	if err := InitJob(); err != nil {
		log.Fatal("Job initialization failed:", err)
	}
}

func main() {
	defer cleanup()

	go Poll()
	for {
		j := <-Jobs
		Busy = true
		if err := RunJob(j); err != nil {
			j.Logger().Println("Job failed:", err)
		}
		Busy = false
	}
}

func cleanup() {
	CleanupObs()
	CleanupOsu()
}
