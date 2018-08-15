package main

import (
	"database/sql"
	"errors"
	"time"

	"replay-bot/shared"

	"github.com/turnage/graw/reddit"
)

var ErrJobNotFound = errors.New("job not found")

// Job is a replay recording and uploading job.
type Job struct {
	shared.Job
	WorkerID  sql.NullString `db:"worker_id"`  // ID of the worker assigned to the job.
	Status    int            `db:"status"`     // Job status.
	Comment   sql.NullString `db:"comment"`    // Justification of status (failure reason, etc.).
	CreatedAt time.Time      `db:"created_at"` // Job creation time.
	UpdatedAt time.Time      `db:"updated_at"` // Job update time.
}

// NewJob creates a new job and assigns it to a worker or the backlog.
func NewJob(p reddit.Post) (*Job, error) {
	now := time.Now()
	job := &Job{
		Job: shared.Job{
			ID:     p.ID,
			Title:  p.Title,
			Author: p.Author,
		},
		CreatedAt: now,
		UpdatedAt: now,
	}
	_, err := GetJob(job.ID)
	if err != nil && err != ErrJobNotFound {
		return nil, err
	}
	if err == nil {
		return nil, errors.New("job already exists")
	}
	// TODO: This all probably belongs in a transaction.
	if err = job.Create(); err != nil {
		return nil, err
	}
	available, err := GetAvailableWorkers()
	if err != nil {
		return nil, err
	}
	if len(available) == 0 {
		job.Status = shared.StatusBacklogged
		if err = job.Update(); err != nil {
			return nil, err
		}
		return job, nil
	}
	worker := chooseWorker(available)
	if err = worker.Assign(job); err != nil {
		return nil, err
	}
	return job, nil
}

// Create saves a new job to the database.
func (j *Job) Create() error {
	now := time.Now()
	if j.CreatedAt.IsZero() {
		j.CreatedAt = now
	}
	if j.UpdatedAt.IsZero() {
		j.UpdatedAt = now
	}
	_, err := db.Exec(
		"insert into jobs(id, worker_id, title, author, status, comment, created_at, updated_at) values ($1, $2, $3, $4, $5, $6, $7, $8)",
		j.ID, j.WorkerID, j.Title, j.Author, j.Status, j.Comment, j.CreatedAt, j.UpdatedAt,
	)
	return err
}

// Update saves changes to a job to the database.
func (j *Job) Update() error {
	j.UpdatedAt = time.Now()
	// We're leaving Title and Author untouched because should should never change.
	_, err := db.Exec(
		"update jobs set worker_id = $1, status = $2, comment = $3, updated_at = $4 where id = $5",
		j.WorkerID, j.Status, j.Comment, j.UpdatedAt, j.ID,
	)
	return err
}

// Finish updates a job's status to complete and clears the worker's current job.
func (j *Job) Finish(w *Worker, status int, comment string) error {
	if status < shared.StatusSuccessful {
		return errors.New("invalid status")
	}
	c := sql.NullString{String: comment, Valid: comment == ""}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	if _, err = tx.Exec(
		"update jobs set status = $1, comment = $2 where id = $3",
		status, c, j.ID,
	); err != nil {
		tx.Rollback()
		return err
	}
	if _, err = tx.Exec(
		"update workers set current_job_id = null where id = $1",
		w.ID,
	); err != nil {
		tx.Rollback()
		return err
	}
	if err = tx.Commit(); err != nil {
		tx.Rollback()
		return err
	}
	j.Status = status
	w.CurrentJobID.Valid = false
	j.Comment = c

	return nil
}

// GetJobs gets all jobs.
func GetJobs() ([]*Job, error) {
	jobs := []*Job{}
	return jobs, db.Select(&jobs, "select * from jobs")
}

// GetJob gets a job by ID.
func GetJob(id string) (*Job, error) {
	job := &Job{}
	err := db.Get(job, "select * from jobs where id = $1", id)
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	if err == sql.ErrNoRows {
		return nil, ErrJobNotFound
	}
	return job, nil
}

// GetActiveJobs gets active jobs.
func GetActiveJobs() ([]*Job, error) {
	jobs := []*Job{}
	return jobs, db.Select(
		&jobs,
		"select * from jobs where worker_id is not null and status between $1 and $2",
		shared.StatusPending, shared.StatusUploading,
	)
}

// GetBacklog gets backlogged jobs.
func GetBacklog() ([]*Job, error) {
	jobs := []*Job{}
	return jobs, db.Select(
		&jobs,
		"select * from jobs where status = $1",
		shared.StatusBacklogged,
	)
}
