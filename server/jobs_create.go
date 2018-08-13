package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"time"
)

// handleJobsCreate handles POST requests to the /jobs/create endpoint.
func handleJobsCreate(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/jobs/create] can't read request body:", err)
		writeText(w, 500, "request body could not be read")
		return
	}

	var m map[string]string
	if err = json.Unmarshal(b, &m); err != nil {
		log.Printf("[/jobs/create] request body '%s' is invalid JSON: %v\n", string(b), err)
		writeText(w, 400, "invalid request body")
		return
	}

	jID, ok := m["id"]
	if !ok {
		log.Println("[/jobs/create] request body is missing job ID")
		writeText(w, 400, "missing required field: 'id'")
		return
	}

	job, err := GetJob(jID)
	if err != nil && err != ErrJobNotFound {
		log.Println("[/jobs/create] couldn't check existing job:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == nil {
		log.Printf("[/jobs/create] job %s already exists\n", job.ID)
		writeText(w, 500, "job already exists")
		return
	}

	now := time.Now()
	job = &Job{
		ID:        jID,
		CreatedAt: now,
		UpdatedAt: now,
	}
	available, err := GetAvailableWorkers()
	if err != nil {
		log.Println("[/jobs/create] couldn't get available workers:", err)
		writeText(w, 500, "database error")
		return
	}
	if len(available) == 0 {
		log.Println("[/jobs/create] no workers available")
		job.Status = statusBacklogged
		if err = job.Create(); err != nil {
			log.Println("[/jobs/create] couldn't create job:", err)
			writeText(w, 500, "database error")
			return
		}
		writeText(w, 200, "job backlogged")
	}

	worker := chooseWorker(available)

	if err = worker.Assign(job); err != nil {
		log.Println("[/jobs/create] couldn't assign job:", err)
		writeText(w, 500, "database error")
		return
	}

	log.Println("[/jobs/create] assigned job to worker", worker.ID)
	writeText(w, 200, "job assigned")
}

// chooseWorker chooses a worker to be assigned to a job.
// TODO: LRU.
func chooseWorker(workers []*Worker) *Worker {
	if len(workers) == 0 {
		return nil
	}
	return workers[rand.Intn(len(workers))]
}
