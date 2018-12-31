package main

import (
	"io/ioutil"
	"log"
	"os"
	"time"
)

// Poll polls for new jobs.
func Poll() {
	for {
		pollOnce()
		time.Sleep(pollInterval)
	}
}

const (
	pollInterval = time.Second * 10
	endpointPoll = "/poll"
)

// Polling logger.
var pollLogger = log.New(os.Stdout, "[poll] ", log.LstdFlags)

// pollOnce polls for a new job.
func pollOnce() {
	resp, err := PostRequest(endpointPoll, map[string]interface{}{"worker": WorkerId}, pollLogger)
	if err != nil {
		return
	}

	if resp.StatusCode == 204 {
		pollLogger.Println("No new job")
		return
	}
	if resp.StatusCode != 200 {
		pollLogger.Println("Bad status code:", resp.StatusCode)
		if b, err := ioutil.ReadAll(resp.Body); err == nil {
			pollLogger.Println("Response body:", string(b))
		}
		return
	}

	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		pollLogger.Println("Couldn't read response body:", err)
		return
	}

	j, err := NewJob(b)
	if err != nil {
		pollLogger.Println("Couldn't create job:", err)
	}

	// If we're busy, assume it's because we're currently doing this job.
	if !Busy {
		Jobs <- j
	}
}
