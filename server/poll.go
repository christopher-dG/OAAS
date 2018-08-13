package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

// handlePoll handles POST requests to the /poll endpoint.
func handlePoll(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/poll] can't read request body:", err)
		writeText(w, 500, "request body could not be read")
		return
	}

	var m map[string]string
	if err = json.Unmarshal(b, &m); err != nil {
		log.Printf("[/poll] request body %s invalid JSON: %v\n", string(b), err)
		writeText(w, 400, "invalid request body")
		return
	}

	wID, ok := m["worker"]
	if !ok {
		log.Println("[/poll] request body is missing worker ID")
		writeText(w, 400, "missing required field: 'worker'")
		return
	}

	worker, err := GetWorker(wID)
	if err != nil && err != ErrWorkerNotFound {
		log.Println("[/poll] couldn't retrieve worker:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == ErrWorkerNotFound {
		worker = &Worker{ID: wID, LastPoll: time.Now()}
		if err = worker.Create(); err != nil {
			log.Println("[/poll] couldn't create worker:", err)
			writeText(w, 500, "database error")
			return
		}
	} else if worker.CurrentJobID.Valid {
		log.Println("[/poll] worker already has a job")
		w.WriteHeader(204)
		return
	} else {
		worker.LastPoll = time.Now()
		worker.Update()
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

	job.Status = statusPending
	if err = job.Update(); err != nil {
		log.Println("[/poll] couldn't update job:", err)
		writeText(w, 500, "database error")
		return
	}

	log.Printf("[/poll] sending job %s to worker %s\n", job.ID, worker.ID)
	writeJSON(w, 200, job)
}
