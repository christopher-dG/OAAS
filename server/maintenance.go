package main

import (
	"log"
	"time"
)

const maintenanceInterval = 10 * time.Minute

// doMaintenance cleans up active jobs that are stalled,
// and moves jobs in the backlog onto free workers.
func doMaintenance() {
	log.Printf("[maintenance] cleaned up %d stalled jobs", cleanupActive())
	log.Printf("[maintenance] scheduled %d backlogged jobs", processBacklog())
}

// Maintenance runs maintenance on an interval.
func Maintenance() {
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
}

// cleanupActive cleans up active jobs that are stalled.
func cleanupActive() int {
	return 0
}

// processBacklog moves jobs in the backlog into free workers.
func processBacklog() int {
	return 0
}
