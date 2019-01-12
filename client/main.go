package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"os/user"
	"path/filepath"
	"syscall"

	yaml "gopkg.in/yaml.v2"
)

var (
	// Logging
	LogWriter io.Writer

	// Configuration
	Config = struct {
		ApiUrl    string `yaml:"api_url"`
		ApiKey    string `yaml:"api_key"`
		ObsOutDir string `yaml:"obs_out_dir"`
		Uploader  string `yaml:"uploader"`
	}{}

	// ID
	WorkerId string

	// State
	Done bool

	// Directories
	DirOsk     string // Skin zips
	DirOsr     string // Replays
	DirOsuBase string // osu! base directory
	DirSkins   string // Skin directories
	DirSongs   string // Map directories
)

func init() {
	// Global: logging
	file, err := os.OpenFile("log.txt", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal("Couldn't open log file: ", err)
	}
	LogWriter = io.MultiWriter(os.Stdout, file)
	log.SetOutput(LogWriter)

	// Global: configuration
	b, err := ioutil.ReadFile("config.yml")
	if err != nil {
		log.Fatal("Couldn't read config file: ", err)
	}
	if err = yaml.Unmarshal(b, &Config); err != nil {
		log.Fatal("Couldn't parse config file: ", err)
	}

	// Global: ID
	if b, err = ioutil.ReadFile("id.txt"); err == nil {
		WorkerId = string(b)
	} else {
		i := rand.Int31n(9999999)
		usr, err := user.Current()
		if err != nil {
			log.Fatal("Couldn't get current user: ", err)
		}
		WorkerId = fmt.Sprintf("%s-%d", usr.Username, i)
		ioutil.WriteFile("id.txt", []byte(WorkerId), 0644)
	}

	// Global: directories
	cwd, err := filepath.Abs(".")
	if err != nil {
		log.Fatal("Couldn't get current folder: ", err)
	}
	DirOsk = filepath.Join(cwd, "osk")
	DirOsr = filepath.Join(cwd, "osr")
	DirOsuBase = filepath.Dir(cwd)
	DirSkins = filepath.Join(DirOsuBase, "Skins")
	DirSongs = filepath.Join(DirOsuBase, "Songs")

	if err := InitOsu(); err != nil {
		log.Fatal("osu! initialization failed: ", err)
	}
}

func main() {
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	go Poll()

	<-stop
	Done = true
	cleanup()
}

func cleanup() {
	CleanupOsu()
}
