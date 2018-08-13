package main

import (
	"database/sql"
	"errors"
	"time"
)

const onlineThreshold = time.Second * 30

var (
	ErrWorkerNotFound = errors.New("worker not found")
	ErrNoJob          = errors.New("no pending job")
)

// Worker is a client that can record and upload replays.
type Worker struct {
	ID           string         `db:"id"`          // Worker ID.
	LastPoll     time.Time      `db:"last_poll"`   // Last poll time.
	CurrentJobID sql.NullString `db:"current_job"` // Job being worked on.
}

// Create saves a new worker to the database.
func (w *Worker) Create() error {
	_, err := db.Exec(
		"insert into workers(id, last_poll) values ($1, $2)",
		w.ID, w.LastPoll,
	)
	return err
}

// Update saves changes to a worker to the database.
func (w *Worker) Update() error {
	_, err := db.Exec(
		"update workers set last_poll = $1, current_job_id = $2 where id = $3",
		w.LastPoll, w.CurrentJobID, w.ID,
	)
	return err
}

// GetPendingJob gets a pending job assigned to the worker.
func (w *Worker) GetPendingJob() (*Job, error) {
	job := &Job{}
	err := db.Get(
		job,
		"select * from jobs where worker_id = $1 and status = $2",
		w.ID, statusPending,
	)
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	if err == sql.ErrNoRows {
		return nil, ErrNoJob
	}
	return job, nil
}

// Online determines whether or not the worker is online.
func (w *Worker) Online() bool {
	return time.Since(w.LastPoll) < onlineThreshold
}

// Available determines whether or not the worker is available to take a new job.
func (w *Worker) Available() bool {
	return w.Online() && !w.CurrentJobID.Valid
}

// Assign assigns a job to the worker.
func (w *Worker) Assign(j *Job) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	if _, err = tx.Exec("update workers set current_job_id = $1 where id = $2",
		j.ID, w.ID,
	); err != nil {
		tx.Rollback()
		return err
	}
	if _, err = tx.Exec(
		"update jobs set status = $1 where id = $2",
		statusPending, j.ID,
	); err != nil {
		tx.Rollback()
		return err
	}
	if err = tx.Commit(); err != nil {
		return err
	}

	if err = w.CurrentJobID.Scan(j.ID); err != nil {
		return err
	}
	j.Status = statusPending
	return nil
}

// GetWorkers gets all workers.
func GetWorkers() ([]*Worker, error) {
	var workers []*Worker
	return workers, db.Select(&workers, "select * from workers")
}

// GetWorker gets a worker by ID.
func GetWorker(id string) (*Worker, error) {
	w := &Worker{}
	err := db.Get(w, "select * from workers where id = $1", id)
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	if err == sql.ErrNoRows {
		return nil, ErrWorkerNotFound
	}
	return w, nil
}

// GetAvailableWorkers gets all workers available to take a new job.
func GetAvailableWorkers() ([]*Worker, error) {
	workers, err := GetWorkers()
	if err != nil {
		return nil, err
	}

	available := []*Worker{}
	for _, w := range workers {
		if w.Available() {
			available = append(available, w)
		}
	}
	return available, nil
}
