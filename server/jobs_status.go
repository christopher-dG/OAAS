package main

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
)

// handleJobsStatus handles POST requests to the /jobs/status endpoint.
func handleJobsStatus(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	b, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Println("[/poll] can't read request body:", err)
		writeText(w, 500, "request body could not be read")
		return
	}

	var m map[string]interface{}
	if err = json.Unmarshal(b, &m); err != nil {
		log.Printf("[/poll] request body %s invalid JSON: %v\n", string(b), err)
		writeText(w, 400, "invalid request body")
		return
	}

	var val interface{}
	var ok bool

	if val, ok = m["worker"]; !ok {
		log.Println("[/poll] request body is missing worker ID")
		writeText(w, 400, "missing required field: 'worker'")
		return
	}
	wID, ok := val.(string)
	if !ok {
		log.Println("/jobs/status] incorrect type for field 'worker'")
		writeText(w, 400, "incorrect type for field 'worker'")
		return
	}

	if val, ok = m["job"]; !ok {
		log.Println("[/poll] request body is missing job ID")
		writeText(w, 400, "missing required field: 'job'")
		return
	}
	jID, ok := val.(string)
	if !ok {
		log.Println("/jobs/status] incorrect type for field 'job'")
		writeText(w, 400, "incorrect type for field 'job'")
		return
	}

	if val, ok = m["status"]; !ok {
		log.Println("[/poll] request body is missing status")
		writeText(w, 400, "missing required field: 'status'")
		return
	}
	status, ok := val.(int)
	if !ok {
		log.Println("/jobs/status] incorrect type for field 'status'")
		writeText(w, 400, "incorrect type for field 'status'")
		return
	}

	if status < statusAcknowledged || status > statusUploading {
		log.Println("[/jobs/status] received invalid status:", status)
		writeText(w, 400, "invalid status")
		return
	}

	worker, err := GetWorker(wID)
	if err != nil && err != ErrWorkerNotFound {
		log.Println("[/jobs/status] couldn't retrieve worker:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == ErrWorkerNotFound {
		// TODO: Can we create a worker and recover from this?
		log.Println("[/jobs/status] worker does not exist:", wID)
		writeText(w, 400, "worker is not registered")
		return
	}

	if !worker.CurrentJobID.Valid || worker.CurrentJobID.String != jID {
		log.Println("[/jobs/status] worker's job and job in request do not match")
		writeText(w, 400, "worker does not own that job")
		return
	}

	job, err := GetJob(jID)
	if err != nil && err != ErrJobNotFound {
		log.Println("[/jobs/status] couldn't retrieve job:", err)
		writeText(w, 500, "database error")
		return
	}
	if err == ErrJobNotFound {
		log.Println("[/jobs/status] job does not exist:", jID)
		writeText(w, 400, "no such job")
		return
	}

	old := job.Status
	job.Status = status
	if err = job.Update(); err != nil {
		log.Println("[/jobs/status] couldn't update job:", err)
		writeText(w, 500, "database error")
		return
	}

	if status > statusUploading {
		worker.CurrentJobID.Valid = false
		if err = worker.Update(); err != nil {
			log.Println("[/jobs/status] couldn't update worker:", err)
			// Don't fail here, the worker should be freed by maintenance soon enough.
		}
	}

	log.Printf("[/jobs/status] updated status of job %s: %d -> %d\n", job.ID, old, status)
	w.WriteHeader(200)
}
