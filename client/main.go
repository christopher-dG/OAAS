package main

import (
	"bytes"
	"crypto/md5"
	"encoding/json"
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
	pollRoute    = "/poll"          // Endpoint to poll for new jobs.
	statusRoute  = "/status"        // Endpoint to update job status.
	pollInterval = time.Second * 10 // Time to wait between polls.
)

var (
	pathFlag   = flag.String("c", "", "path to configuration file") // Config path flag.
	httpClient = http.Client{Timeout: time.Second * 10}             // HTTP client.
	httpLogger = log.New(os.Stdout, "[http] ", log.LstdFlags)       // Logger for HTTP requests.
	pollLogger = log.New(os.Stdout, "[/poll] ", log.LstdFlags)      // Logger for polling.

	// Runtime configuration.
	config = func() ConfigFile {
		flag.Parse()
		if *pathFlag == "" {
			log.Fatal("required option -c is missing")
		}
		b, err := ioutil.ReadFile(*pathFlag)
		var c ConfigFile
		if err = yaml.Unmarshal(b, &c); err != nil {
			log.Fatal(err)
		}
		return c
	}()

	username = func() string {
		usr, err := user.Current()
		if err != nil {
			log.Fatal("couldn't get username;", err)
		}
		return usr.Username
	}()

	// Unique identifier for this worker.
	workerID = func() string {
		path := filepath.Join(config.OsuRoot, "rf-token")
		token, err := ioutil.ReadFile(path)
		if err != nil {
			token = []byte(fmt.Sprintf("%x", md5.Sum([]byte(strconv.Itoa(int(time.Now().Unix()))))))[:8]
			ioutil.WriteFile(path, token, 0400)
		}
		return fmt.Sprintf("%s-%s", username, string(token))
	}()
)

func main() {
	log.Println("Worker ID:", workerID)
	jobs := make(chan Job)
	go poll(jobs)
	for {
		go (<-jobs).Process()
	}
}

// poll calls the /poll endpoint to register presence and check for new work.
func poll(jobs chan Job) {
	for {
		pollOnce(jobs)
		time.Sleep(pollInterval)
	}
}

func headers(r *http.Request) {
	r.Header.Set("Content-Type", "application/json")
	r.Header.Set("Authorization", config.ApiKey)
}

func pollOnce(jobs chan Job) {
	b := []byte(fmt.Sprintf(`{"worker":"%s"}`, workerID))
	req, err := http.NewRequest(http.MethodPost, config.ApiURL+pollRoute, bytes.NewBuffer(b))
	if err != nil {
		pollLogger.Println("couldn't create request:", err)
		return
	}
	headers(req)

	resp, err := httpClient.Do(req)
	if err != nil {
		pollLogger.Println("error making request:", err)
		return
	}

	defer resp.Body.Close()
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		pollLogger.Println("couldn't read response body:", err)
		return
	}

	if resp.StatusCode != 200 && resp.StatusCode != 204 {
		pollLogger.Println("unexpected status code:", strconv.Itoa(resp.StatusCode))
		pollLogger.Println("body:", string(respBody))
		return
	}

	if resp.StatusCode == 204 {
		pollLogger.Println("no new job")
		return
	}

	if err != nil {
		pollLogger.Println("couldn't read response body:", err)
		return
	}

	var j Job
	if err = json.Unmarshal(respBody, &j); err != nil {
		pollLogger.Println("couldn't decode response body:", err)
		return
	}

	jobs <- j
}

// updateStatus sends a request to update the job's status.
func updateStatus(j Job, status int, comment string) error {
	log.Println("updating status ->", StatusMap[status])
	_, err := postStatus(map[string]interface{}{
		"worker":  workerID,
		"job":     j.ID,
		"status":  status,
		"comment": comment,
	})
	return err
}

// fail updates the job status to FAILED.
func fail(j Job, context string, err error) {
	comment := fmt.Sprintf("%s: %v", context, err)
	log.Println(comment)
	updateStatus(j, StatusFailed, comment)
}

// postJobsStatus makes an HTTP POST request to the API's /jobs/status endpoint.
func postStatus(body map[string]interface{}) (*http.Response, error) {
	httpLogger.Println("POST:", statusRoute)

	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	httpLogger.Println("request body:", string(b))

	req, err := http.NewRequest(http.MethodPost, config.ApiURL+statusRoute, bytes.NewBuffer(b))
	if err != nil {
		return nil, err
	}
	headers(req)

	resp, err := httpClient.Do(req)
	if err == nil {
		httpLogger.Println("status code:", resp.StatusCode)
	}

	return resp, err
}

// httpGet makes a GET request and returns the body.
func httpGet(url string) ([]byte, error) {
	httpLogger.Println("GET:", url)
	resp, err := httpClient.Get(url)
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
