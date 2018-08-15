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
}

// validateJobsStatus checks that the the request is valid.
func validateJobsStatus(w http.ResponseWriter, r *http.Request) *JobsStatusRequest {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/poll] can't read request body:", err)
		writeText(w, 500, "request body could not be read")
		return nil
	}
	req := &JobsStatusRequest{}
	if err = json.Unmarshal(b, req); err != nil {
		log.Println("[/jobs/status] invalid request body:", err)
		writeText(w, 400, "invalid request body")
		return nil
	}
	if req.WorkerID == "" {
		log.Println("[/poll] request body is missing 'worker' field")
		writeText(w, 400, "missing required field 'worker'")
		return nil
	}
	if req.JobID == "" {
		log.Println("[/poll] request body is missing 'job' field")
		writeText(w, 400, "missing required field 'job'")
		return nil
	}
	if req.Status == 0 {
		log.Println("[/poll] request body is missing 'status' field (or it is 0)")
		writeText(w, 400, "missing required field 'status'")
		return nil
	}
	if req.Status < shared.StatusAcknowledged || req.Status > shared.StatusFailed {
		log.Println("[/jobs/status] received invalid status:", req.Status)
		writeText(w, 400, "invalid status")
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
		writeText(w, 500, "database error")
		return
	}
	if err == ErrWorkerNotFound {
		// TODO: Can we create a worker and recover from this?
		log.Println("[/jobs/status] worker does not exist:", req.WorkerID)
		writeText(w, 400, "worker is not registered")
		return
	}

	if !worker.CurrentJobID.Valid || worker.CurrentJobID.String != req.JobID {
		log.Println("[/jobs/status] worker's job and job in request do not match")
		writeText(w, 400, "worker is not assigned that job")
		return
	}

	job, err := GetJob(req.JobID)
	if err != nil && err != ErrJobNotFound {
		log.Println("[/jobs/status] couldn't retrieve job:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == ErrJobNotFound {
		log.Println("[/jobs/status] job does not exist:", req.JobID)
		writeText(w, 400, "no such job")
		return
	}

	old := job.Status

	if req.Status >= shared.StatusSuccessful {
		if err = job.Finish(worker, req.Status); err != nil {
			log.Println("[/jobs/status] couldn't finish job:", err)
			writeText(w, 500, "database error")
			return
		}
	} else {
		job.Status = req.Status
		if err = job.Update(); err != nil {
			log.Println("[/jobs/status] couldn't update job:", err)
			writeText(w, 500, "database error")
			return
		}
	}

	log.Printf("[/jobs/status] updated status of job %s: %d -> %d\n", job.ID, old, req.Status)
	w.WriteHeader(200)
}
