package main

import (
	"database/sql"
	"errors"
	"time"
)

var ErrJobNotFound = errors.New("no job found")

// Job is a replay recording and uploading job.
type Job struct {
	ID        string         `db:"id"`         // Reddit ID of the post the job corresponds to.
	WorkerID  sql.NullString `db:"worker_id"`  // ID of the worker assigned to the job.
	Status    int            `db:"status"`     // Job status.
	Comment   sql.NullString `db:"comment"`    // Justification of status (failure reason, etc.).
	CreatedAt time.Time      `db:"created_at"` // Job creation time.
	UpdatedAt time.Time      `db:"updated_at"` // Job update time.
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
		"insert into jobs(id, worker_id, status) values ($1, $2, $3, $4, $5, $6)",
		j.ID, j.WorkerID, j.Status, j.Comment, j.CreatedAt, j.UpdatedAt,
	)
	return err
}

// Update saves changes to a job to the database.
func (j *Job) Update() error {
	j.UpdatedAt = time.Now()
	_, err := db.Exec(
		"update jobs set worker_id = $1, status = $2, comment = $3, updated_at = $4 where id = $5",
		j.WorkerID, j.Status, j.Comment, j.UpdatedAt, j.ID,
	)
	return err
}

// Finish updates a job's status to complete and clears the worker's current job.
func (j *Job) Finish(w *Worker, status int) error {
	if status < statusSuccessful {
		return errors.New("invalid status")
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	if _, err = tx.Exec(
		"update jobs set status = $1 where id = $2",
		status, j.ID,
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
		statusPending, statusUploading,
	)
}
