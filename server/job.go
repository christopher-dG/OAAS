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

// NewJob creates a new job and assigns it to a worker if possible.
func NewJob(id string) (*Job, error) {
	now := time.Now()
	job := &Job{
		ID:        id,
		Status:    statusPending,
		CreatedAt: now,
		UpdatedAt: now,
	}

	return job, nil
}

// Create saves a new job to the database.
func (j *Job) Create() error {
	_, err := db.Exec(
		"insert into jobs(id, worker, status) values ($1, $2, $3)",
		j.ID, j.WorkerID, j.Status,
	)
	return err
}

// Update saves changes to a job to the database.
func (j *Job) Update() error {
	j.UpdatedAt = time.Now()
	_, err := db.Exec(
		"update jobs set worker = $1, status = $2, updated_at = $3 where id = $4",
		j.WorkerID, j.Status, j.UpdatedAt, j.ID,
	)
	return err
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
		"select * from jobs where worker is not null and status between $1 and $2",
		statusPending, statusUploading,
	)
}
