package main

import (
	"encoding/json"
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

// writeJSON writes a JSON response to the response writer.
func writeJSON(w http.ResponseWriter, content interface{}, status int) {
	b, err := json.Marshal(content)
	if err != nil {
		log.Printf("[http] couldn't encode content '%v': %v\n", content, err)
		http.Error(w, "error encoding response", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(status)
	w.Write(b)
}
