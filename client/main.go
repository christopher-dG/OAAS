package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"strconv"
	"time"

	obs "github.com/christopher-dG/go-obs-websocket"
	"github.com/go-vgo/robotgo"
	yaml "gopkg.in/yaml.v2"
)

const (
	// HTTP stuff.
	routePoll    = "/poll"          // Endpoint for job polling.
	routeStatus  = "/status"        // Endpoint for status endpoint.
	pollInterval = time.Second * 10 // Time between requests to routePoll.

	// OBS stuff.
	obsPort   = 4444   // The default OBS websocket port.
	obsScene  = "OAAS" // Default OBS scene.
	obsFormat = ".mp4" // Video format for exports.

	// osu! stuff.
	replayScaleX = 0.8546875
	replayScaleY = 0.7555555555555555
	graphScaleX  = 0.41354166666666664
	graphScaleY  = 0.8296296296296296

	// Skin stuff.
	defaultSkin = "oaas.osk"
)

var (
	// CLI stuff.
	pathFlag = flag.String("c", "config.yml", "path to configuration file")

	// Config stuff.
	config   ConfigFile
	workerID string
	localDir string

	// State stuff.
	isWorking = false

	// Job prep stuff.
	replayDir  string
	skinDir    string
	beatmapDir string

	// osu! stuff.
	osuExe       string
	startReplayX int
	startReplayY int
	showGraphX   int
	showGraphY   int

	// Logging stuff.
	pollLogger = log.New(os.Stdout, "[/poll] ", log.LstdFlags)

	// Recording stuff.
	obsClient obs.Client
	obsFolder string
)

func init() {
	// Parse/validate CLI arguments.
	flag.Parse()
	if *pathFlag == "" {
		log.Fatal("option -c <config-file> is missing")
	}

	// Load the config.
	b, err := ioutil.ReadFile(*pathFlag)
	if err != nil {
		log.Fatal(err)
	}
	if err = yaml.Unmarshal(b, &config); err != nil {
		log.Fatal(err)
	}
	if err = config.Validate(); err != nil {
		log.Fatal(err)
	}

	localDir = filepath.Join(config.OsuRoot, "OAAS")
	os.MkdirAll(localDir, os.ModePerm)

	// Read or create the worker ID.
	path := filepath.Join(localDir, "oaas-id")
	if b, err = ioutil.ReadFile(path); err == nil {
		workerID = string(b)
	} else {
		// Generate new ID.
		usr, err := user.Current()
		if err != nil {
			log.Fatal("couldn't get username;", err)
		}
		token := strconv.Itoa(int(time.Now().UnixNano()))
		workerID = usr.Username + "-" + token
		ioutil.WriteFile(path, []byte(workerID), 0400)
	}

	// Compute/create the necessary directories.
	beatmapDir = filepath.Join(config.OsuRoot, "Songs")
	replayDir = filepath.Join(localDir, "osr")
	skinDir = filepath.Join(localDir, "osk")
	os.MkdirAll(replayDir, os.ModePerm)
	os.MkdirAll(skinDir, os.ModePerm)

	// Set up the OBS client, set the scene, and get the recording folder.
	obsClient = obs.Client{Host: "localhost", Port: config.OBSPort, Password: config.OBSPassword}
	if err = obsClient.Connect(); err != nil {
		log.Fatal("couldn't connect to OBS:", err)
	}
	_, err = obs.NewSetCurrentSceneRequest(obsScene).SendReceive(obsClient)
	if err != nil {
		log.Fatal(err)
	}
	resp, err := obs.NewGetRecordingFolderRequest().SendReceive(obsClient)
	if err != nil {
		log.Fatal(err)
	}
	obsFolder = resp.RecFolder

	// Determine the osu! executable.
	if runtime.GOOS == "windows" {
		osuExe = "osu!.exe"
	} else {
		osuExe = "osu!"
	}

	// Compute the pixel offsets.
	sizeXi, sizeYi := robotgo.GetScreenSize()
	sizeX, sizeY := float64(sizeXi), float64(sizeYi)
	startReplayX = int(math.Round(sizeX * replayScaleX))
	startReplayY = int(math.Round(sizeY * replayScaleY))
	showGraphX = int(math.Round(sizeX * graphScaleX))
	showGraphY = int(math.Round(sizeY * graphScaleY))
}

func main() {
	ExecOsu()
	time.Sleep(time.Second * 3)

	fmt.Println("==============================================================================")
	fmt.Println("==============================================================================")
	fmt.Println("if you can still read this message, click on the open osu! window to focus it!")
	fmt.Println("==============================================================================")
	fmt.Println("==============================================================================")

	log.Println("Worker ID:", workerID)

	defer obsClient.Disconnect()
	jobs := make(chan Job)

	go poll(jobs)
	for {
		j := <-jobs
		isWorking = true
		j.Process()
		isWorking = false
	}
}

// oaasHeaders adds the necessary headers for the OAAS API.
func oaasHeaders(r *http.Request) {
	r.Header.Set("Content-Type", "application/json")
	r.Header.Set("Authorization", config.ApiKey)
}

// httpGetBody makes a GET request and returns the body.
func httpGetBody(url string) ([]byte, error) {
	log.Println("GET:", url)
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("non-200 status code %d", resp.StatusCode)
	}
	return ioutil.ReadAll(resp.Body)
}
