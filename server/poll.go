package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"replay-bot/shared"
	"time"
)

// PollRequest contains the request body for /poll requests.
type PollRequest struct {
	WorkerID string `json:"worker"`
}

// validatePoll checks that the the request is valid.
func validatePoll(w http.ResponseWriter, r *http.Request) *PollRequest {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/poll] can't read request body:", err)
		writeText(w, 500, "request body could not be read")
		return nil
	}
	req := &PollRequest{}
	if err = json.Unmarshal(b, req); err != nil {
		log.Println("[/poll] invalid request body:", err)
		writeText(w, 400, "invalid request body")
		return nil
	}
	if req.WorkerID == "" {
		log.Println("[/poll] request body is missing 'worker' field")
		writeText(w, 400, "missing required field 'worker'")
		return nil
	}
	return req
}

// handlePoll handles POST requests to the /poll endpoint.
func handlePoll(w http.ResponseWriter, r *http.Request) {
	req := validatePoll(w, r)
	if req == nil {
		return
	}

	worker, err := GetWorker(req.WorkerID)
	if err != nil && err != ErrWorkerNotFound {
		log.Println("[/poll] couldn't retrieve worker:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == ErrWorkerNotFound {
		worker = &Worker{ID: req.WorkerID, LastPoll: time.Now()}
		if err = worker.Create(); err != nil {
			log.Println("[/poll] couldn't create worker:", err)
			writeText(w, 500, "database error")
			return
		}
		log.Println("[/poll] created new worker", worker.ID)
	} else {
		worker.LastPoll = time.Now()
		worker.Update()
	}

	if worker.CurrentJobID.Valid {
		log.Println("[/poll] worker already has a job")
		w.WriteHeader(204)
		return
	}

	job, err := worker.GetPendingJob()
	if err != nil && err != ErrNoJob {
		log.Println("[/poll] couldn't get pending job:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == ErrNoJob {
		log.Println("[/poll] no new job for worker", worker.ID)
		w.WriteHeader(204)
		return
	}

	job.Status = shared.StatusPending
	if err = job.Update(); err != nil {
		log.Println("[/poll] couldn't update job:", err)
		writeText(w, 500, "database error")
		return
	}

	log.Printf("[/poll] sending job %s to worker %s\n", job.ID, worker.ID)
	writeJSON(w, 200, job)
}
