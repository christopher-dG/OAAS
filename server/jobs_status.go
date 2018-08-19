package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"

	"replay-bot/shared"
)

// JobsStatusRequest contains the request body for /jobs/status requests.
type JobsStatusRequest struct {
	WorkerID string `json:"worker"`
	JobID    string `json:"job"`
	Status   int    `json:"status"`
	Comment  string `json:"comment"`
}

// validateJobsStatus checks that the the request is valid.
func validateJobsStatus(w http.ResponseWriter, r *http.Request) *JobsStatusRequest {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/poll] can't read request body:", err)
		http.Error(w, "request body could not be read", http.StatusInternalServerError)
		return nil
	}
	req := &JobsStatusRequest{}
	if err = json.Unmarshal(b, req); err != nil {
		log.Println("[/jobs/status] invalid request body:", err)
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return nil
	}
	if req.WorkerID == "" {
		log.Println("[/poll] request body is missing 'worker' field")
		http.Error(w, "missing required field 'worker'", http.StatusBadRequest)
		return nil
	}
	if req.JobID == "" {
		log.Println("[/poll] request body is missing 'job' field")
		http.Error(w, "missing required field 'job'", http.StatusBadRequest)
		return nil
	}
	if req.Status == 0 {
		log.Println("[/poll] request body is missing 'status' field (or it is 0)")
		http.Error(w, "missing required field 'status'", http.StatusBadRequest)
		return nil
	}
	if req.Status < shared.StatusAcknowledged || req.Status > shared.StatusFailed {
		log.Println("[/jobs/status] received invalid status:", req.Status)
		http.Error(w, "invalid status", http.StatusBadRequest)
		return nil
	}
	return req
}

// handleJobsStatus handles POST requests to the /jobs/status endpoint.
func handleJobsStatus(w http.ResponseWriter, r *http.Request) {
	req := validateJobsStatus(w, r)
	if req == nil {
		return
	}

	worker, err := GetWorker(req.WorkerID)
	if err != nil && err != ErrWorkerNotFound {
		log.Println("[/jobs/status] couldn't retrieve worker:", err)
		http.Error(w, "database error", http.StatusInternalServerError)
		return
	}
	if err == ErrWorkerNotFound {
		// TODO: Can we create a worker and recover from this?
		log.Println("[/jobs/status] worker does not exist:", req.WorkerID)
		http.Error(w, "worker is not registered", http.StatusBadRequest)
		return
	}

	if !worker.CurrentJobID.Valid || worker.CurrentJobID.String != req.JobID {
		log.Println("[/jobs/status] worker's job and job in request do not match")
		http.Error(w, "worker is not assigned that job", http.StatusBadRequest)
		return
	}

	job, err := GetJob(req.JobID)
	if err != nil && err != ErrJobNotFound {
		log.Println("[/jobs/status] couldn't retrieve job:", err)
		http.Error(w, "database error", http.StatusInternalServerError)
		return
	}
	if err == ErrJobNotFound {
		log.Println("[/jobs/status] job does not exist:", req.JobID)
		http.Error(w, "no such job", http.StatusBadRequest)
		return
	}

	old := job.Status

	if req.Status >= shared.StatusSuccessful {
		if err = job.Finish(worker, req.Status, req.Comment); err != nil {
			log.Println("[/jobs/status] couldn't finish job:", err)
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}
	} else {
		job.Status = req.Status
		if err = job.Update(); err != nil {
			log.Println("[/jobs/status] couldn't update job:", err)
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}
	}

	log.Printf("[/jobs/status] updated status of job %s: %d -> %d\n", job.ID, old, req.Status)
	w.WriteHeader(http.StatusOK)
}
