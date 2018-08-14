package main

import (
	"log"
	"net/http"
	"strconv"
)

const port = 4000

// StartHTTP starts the HTTP server.
func StartHTTP() chan bool {
	http.HandleFunc("/poll", handlePoll)
	http.HandleFunc("/jobs/status", handleJobsStatus)
	done := make(chan bool)
	go func() {
		log.Println("[http] starting HTTP server on port", strconv.Itoa(port))
		log.Println(
			"HTTP server terminating:",
			http.ListenAndServe(":"+strconv.Itoa(port), nil),
		)
		done <- true
	}()
	return done
}
