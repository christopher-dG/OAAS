package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

const (
	pollRoute    = "/poll"          // Endpoint to poll for new jobs.
	pollInterval = time.Second * 10 // Time to wait between polls.
)

var pollLogger = log.New(os.Stdout, "[/poll] ", log.LstdFlags) // Logger for polling.

// poll calls pollOnce continuously.
func poll(jobs chan Job) {
	for {
		pollOnce(jobs)
		time.Sleep(pollInterval)
	}
}

// poll POSTs to the /poll endpoint to register presence and check for a new job.
func pollOnce(jobs chan Job) {
	b, err := json.Marshal(map[string]string{"worker": workerID})
	if err != nil {
		pollLogger.Println("")
		return
	}

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
