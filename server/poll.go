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
		http.Error(w, "request body could not be read", http.StatusInternalServerError)
		return nil
	}
	req := &PollRequest{}
	if err = json.Unmarshal(b, req); err != nil {
		log.Println("[/poll] invalid request body:", err)
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return nil
	}
	if req.WorkerID == "" {
		log.Println("[/poll] request body is missing 'worker' field")
		http.Error(w, "missing required field 'worker'", http.StatusBadRequest)
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
		http.Error(w, "database error", http.StatusInternalServerError)
		return
	}
	if err == ErrWorkerNotFound {
		worker = &Worker{ID: req.WorkerID, LastPoll: time.Now()}
		if err = worker.Create(); err != nil {
			log.Println("[/poll] couldn't create worker:", err)
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}
		log.Println("[/poll] created new worker", worker.ID)
	} else {
		worker.LastPoll = time.Now()
		worker.Update()
	}

	job, err := worker.GetAssignedJob()
	if err != nil && err != ErrNoJob {
		log.Println("[/poll] couldn't get pending job:", err)
		http.Error(w, "database error", http.StatusInternalServerError)
		return
	}
	if err == ErrNoJob {
		log.Println("[/poll] no new job for worker", worker.ID)
		w.WriteHeader(http.StatusNoContent)
		return
	}

	if job.Status != shared.StatusAssigned {
		log.Println("[/poll] worker is already working on a job")
		w.WriteHeader(http.StatusNoContent)
		return
	}

	job.Status = shared.StatusPending
	if err = job.Update(); err != nil {
		log.Println("[/poll] couldn't update job:", err)
		http.Error(w, "database error", http.StatusInternalServerError)
		return
	}

	log.Printf("[/poll] sending job %s to worker %s\n", job.ID, worker.ID)
	writeJSON(w, job, http.StatusOK)
}
