package main

import (
	"log"
	"net/http"
	"strconv"
	"sync"
)

const port = 4000

var (
	wg   = sync.WaitGroup{}
	done = make(chan bool)
)

func main() {
	http.HandleFunc("/poll", handlePoll)
	http.HandleFunc("/jobs/create", handleJobsCreate)
	http.HandleFunc("/jobs/status", handleJobsCreate)

	go Maintenance()

	log.Println(http.ListenAndServe(":"+strconv.Itoa(port), nil))
	done <- true
	wg.Wait()
}
