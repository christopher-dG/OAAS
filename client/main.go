package main

import (
	"crypto/md5"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os/user"
	"path/filepath"
	"strconv"
	"time"

	yaml "gopkg.in/yaml.v2"
)

var (
	pathFlag = flag.String("c", "", "path to configuration file") // Config path flag.

	config   ConfigFile // Runtime configuration.
	localDir string     // Directory for local data.
	username string     // Worker's username (used for osu! config file and worker ID).
	workerID string     // Unique identifier for this worker.
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

	localDir = filepath.Join(config.OsuRoot, "Replay Farm")

	usr, err := user.Current()
	if err != nil {
		log.Fatal("couldn't get username;", err)
	}
	username = usr.Username

	path := filepath.Join(localDir, "id-token")
	token, err := ioutil.ReadFile(path)
	if err != nil {
		token = []byte(fmt.Sprintf("%x", md5.Sum([]byte(strconv.Itoa(int(time.Now().Unix()))))))[:8]
		ioutil.WriteFile(path, token, 0400)
	}
	workerID = fmt.Sprintf("%s-%s", username, string(token))
}

func main() {
	log.Println("Worker ID:", workerID)
	jobs := make(chan Job)
	go poll(jobs)
	for {
		go (<-jobs).Process()
	}
}
