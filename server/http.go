package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
)

const port = 4000

var keys = func() []string {
	var keys []string
	if err := db.Select(&keys, "select key from keys"); err != nil {
		log.Fatal(err)
	}
	return keys
}()

// StartHTTP starts the HTTP server.
func StartHTTP() chan bool {
	http.HandleFunc("/poll", authenticate(handlePoll))
	http.HandleFunc("/jobs/status", authenticate(handleJobsStatus))
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

// authenticate validates a request's API key.
func authenticate(fn http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("Authorization")
		if key == "" {
			http.Error(w, "missing API key", http.StatusUnauthorized)
			return
		}
		for _, k := range keys {
			if key == k {
				fn(w, r)
				return
			}
		}
		http.Error(w, "invalid API key", http.StatusUnauthorized)
		return
	}
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
