package main

import (
	"log"
	"time"

	"replay-bot/shared"
)

const maintenanceInterval = time.Second * 10

var thresholds = map[int]time.Duration{
	shared.StatusAssigned:     time.Minute,
	shared.StatusPending:      time.Minute,
	shared.StatusAcknowledged: time.Minute * 5,
	shared.StatusRecording:    time.Minute * 30,
	shared.StatusUploading:    time.Hour,
}

// doMaintenance cleans up active jobs that are stalled,
// and moves jobs in the backlog onto free workers.
func doMaintenance() {
	active := cleanupActive()
	backlog := processBacklog()
	log.Printf("[maintenance] cleaned up %d stalled jobs", active)
	log.Printf("[maintenance] scheduled %d backlogged jobs", backlog)
}

// StartMaintenance runs maintenance on an interval.
func StartMaintenance() chan bool {
	done := make(chan bool)
	go func() {
		log.Println("[maintenance] starting maintenance loop to run every", maintenanceInterval)
		for {
			select {
			case <-done:
				return
			case <-time.After(maintenanceInterval):
				wg.Add(1)
				doMaintenance()
				wg.Done()
			}
		}
	}()
	return done
}

// cleanupActive cleans up active jobs that are stalled.
func cleanupActive() int {
	jobs, err := GetActiveJobs()
	if err != nil {
		log.Println("[maintenance] couldn't get active jobs:", err)
		return 0
	}

	if len(jobs) == 0 {
		log.Println("[maintenance] no active jobs to clean up")
		return 0
	}

	workers, err := workerMap()
	if err != nil {
		log.Println("[maintenance] couldn't get workers:", err)
		return 0
	}

	count := 0
	for _, j := range jobs[:] {
		w, ok := workers[j.WorkerID.String]
		if !ok {
			log.Printf("[maintenance] active job %s has no worker\n", j.ID)
			continue
		}

		if time.Since(j.UpdatedAt) > thresholds[j.Status] {
			log.Printf("[maintenance] cleaning up job %s (timeout)\n", j.ID)
			if err = j.Finish(w, shared.StatusFailed, "timeout"); err != nil {
				log.Println("[maintenance] couldn't clean up job:", err)
			}
			DiscordSendf("Job `%s` assigned to worker `%s` timed out.", j.ID, w.ID)
			count++
			continue
		}
		if !workers[j.WorkerID.String].Online() {
			log.Printf("[maintenance] cleaning up job %s (worker offline)\n", j.ID)
			if err = j.Finish(w, shared.StatusFailed, "worker offline"); err != nil {
				log.Println("[maintenance] couldn't clean up job:", err)
			}
			DiscordSendf("Worker `%s` went offline while assigned job `%s`.", w.ID, j.ID)
			count++
			continue
		}
	}

	return count
}

// processBacklog moves jobs in the backlog into free workers.
func processBacklog() int {
	jobs, err := GetBacklog()
	if err != nil {
		log.Println("[maintenance] couldn't get backlog:", err)
		return 0
	}
	if len(jobs) == 0 {
		log.Println("[maintenance] no backlog to process")
		return 0
	}

	workers, err := GetAvailableWorkers()
	if err != nil {
		log.Println("[maintenance] couldn't get available workers:", err)
		return 0
	}
	if len(workers) == 0 {
		log.Println("[maintenance] no workers available to process backlog")
		return 0
	}

	count := 0
	for _, j := range jobs {
		w := ChooseWorker(workers)
		if err = w.Assign(j); err != nil {
			log.Println(
				"[maintenance] couldn't assign job %s to worker %s: %v",
				j.ID, w.ID, err,
			)
			continue
		}
		DiscordSendf("Assigned job `%s` to worker `%s` from backlog.", j.ID, w.ID)
		count++
	}

	return count
}

// workerMap returns a map from worker ID to worker.
func workerMap() (map[string]*Worker, error) {
	workers, err := GetWorkers()
	if err != nil {
		return nil, err
	}
	m := make(map[string]*Worker)
	for _, w := range workers {
		m[w.ID] = w
	}
	return m, nil
}
