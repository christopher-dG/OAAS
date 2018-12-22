package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"strconv"
	"time"
)

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

	req, err := http.NewRequest(http.MethodPost, config.ApiURL+routePoll, bytes.NewBuffer(b))
	if err != nil {
		pollLogger.Println("couldn't create request:", err)
		return
	}
	rfHeaders(req)
	resp, err := http.DefaultClient.Do(req)
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

	if isWorking || resp.StatusCode == 204 {
		pollLogger.Println("no new job")
		return
	}

	var j Job
	if err = json.Unmarshal(respBody, &j); err != nil {
		pollLogger.Println("couldn't decode response body:", err)
		return
	}

	jobs <- j
}
