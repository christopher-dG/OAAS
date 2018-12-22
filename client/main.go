package main

import (
	"crypto/md5"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"strconv"
	"time"

	yaml "gopkg.in/yaml.v2"
)

const (
	routePoll    = "/poll"           // Endpoint for job polling.
	routeStatus  = "/status"         // Endpoint for status endpoint.
	pollInterval = time.Second * 10  // Time between requests to routePoll.
	defaultSkin  = "rf-default-skin" // osu! skin to be used when none is provided.
	defaultPort  = 4444              // The default OBS websocket port.
)

var (
	pathFlag = flag.String("c", "", "path to configuration file") // Config path flag.

	config   ConfigFile // Runtime configuration.
	localDir string     // Directory for local data.
	username string     // Worker's username (used for osu! config file and worker ID).
	workerID string     // Unique identifier for this worker.

	isWorking = false // True whenever the worker is doing a job.

	// Job preparation
	skinsDir    = filepath.Join(config.OsuRoot, "Skins")                             // Skin directory.
	beatmapsDir = filepath.Join(config.OsuRoot, "Songs")                             // Beatmap directory.
	osuCfg      = filepath.Join(config.OsuRoot, fmt.Sprintf("osu.%s.cfg", username)) // osu! config file.

	pollLogger = log.New(os.Stdout, "[/poll] ", log.LstdFlags) // Logger for polling.
)

func init() {
	flag.Parse()
	if *pathFlag == "" {
		log.Fatal("required option -c <config-file> is missing")
	}
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

	localDir = filepath.Join(config.OsuRoot, "replay-farm")

	usr, err := user.Current()
	if err != nil {
		log.Fatal("couldn't get username;", err)
	}
	username = usr.Username

	path := filepath.Join(localDir, "rf-token")
	log.Println(path)
	token, err := ioutil.ReadFile(path)
	if err != nil {
		token = []byte(fmt.Sprintf("%x", md5.Sum([]byte(strconv.Itoa(int(time.Now().Unix()))))))[:8]
		ioutil.WriteFile(path, token, 0400)
	}
	workerID = fmt.Sprintf("%s-%s", username, string(token))

	skinsDir = filepath.Join(config.OsuRoot, "Skins")
	beatmapsDir = filepath.Join(config.OsuRoot, "Songs")
	osuCfg = filepath.Join(config.OsuRoot, fmt.Sprintf("osu.%s.cfg", username))
}

func main() {
	log.Println("Worker ID:", workerID)
	jobs := make(chan Job)

	go poll(jobs)
	for {
		j := <-jobs
		isWorking = true
		j.Process()
		isWorking = false
	}
}

// rfHeaders adds the necessary headers for the Replay Farm API.
func rfHeaders(r *http.Request) {
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
	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return b, nil
}
