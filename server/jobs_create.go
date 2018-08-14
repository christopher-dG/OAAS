package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"time"
)

// JobsCreateRequest contains the request body for /jobs/create requests.
type JobsCreateRequest struct {
	JobID string `json:"job"`
}

// validateJobsCreate checks that the the request is valid.
func validateJobsCreate(w http.ResponseWriter, r *http.Request) *JobsCreateRequest {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/jobs/create] can't read request body:", err)
		writeText(w, 500, "request body could not be read")
		return nil
	}
	req := &JobsCreateRequest{}
	if err = json.Unmarshal(b, req); err != nil {
		log.Println("[/jobs/create] invalid request body:", err)
		writeText(w, 400, "invalid request body")
		return nil
	}
	if req.JobID == "" {
		log.Println("[/poll] request body is missing 'job' field")
		writeText(w, 400, "missing required field 'job'")
		return nil
	}
	return req
}

// handleJobsCreate handles POST requests to the /jobs/create endpoint.
func handleJobsCreate(w http.ResponseWriter, r *http.Request) {
	req := validateJobsCreate(w, r)
	if req == nil {
		return
	}

	job, err := GetJob(req.JobID)
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
		ID:        req.JobID,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err = job.Create(); err != nil {
		log.Println("[jobs/create] couldn't create job:", err)
		writeText(w, 500, "database error")
		return
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
		if err = job.Update(); err != nil {
			log.Println("[/jobs/create] couldn't update job:", err)
			writeText(w, 500, "database error")
			return
		}
		log.Printf("[/jobs/create] added job %s to backlog\n", job.ID)
		writeText(w, 200, "job backlogged")
		return
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
