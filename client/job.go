package main

import (
	"encoding/json"
	"fmt"
	"log"
)

const (
	StatusPreparing  = 2
	StatusExecuting  = 3
	StatusCleanup    = 4
	StatusRecording  = 5
	StatusUploading  = 6
	StatusSuccessful = 7
	StatusFailed     = 8
)

// JobBase is common job data.
type JobBase struct {
	id      int
	logger  *log.Logger
	comment string
}

// Id returns the job's ID.
func (j *JobBase) Id() int {
	return j.id
}

// Logger returns the job logger.
func (j *JobBase) Logger() *log.Logger {
	return j.logger
}

// Comment gets the job's comment.
func (j *JobBase) Comment() string {
	return j.comment
}

// SetComment sets the job's comment.
func (j *JobBase) SetComment(s string) {
	j.comment = s
}

// Prepare prepares the job.
func (j *JobBase) Prepare() error {
	j.Logger().Println("Prepare: Nothing to do")
	return nil
}

// Execute executes the job.
func (j *JobBase) Execute() error {
	j.Logger().Println("Execute: Nothing to do")
	return nil
}

// Cleanup cleans up the job.
func (j *JobBase) Cleanup() error {
	j.Logger().Println("Cleanup: Nothing to do")
	return nil
}

// Job is a task to be completed by the worker.
type Job interface {
	Id() int
	Logger() *log.Logger
	Comment() string
	SetComment(string)
	Prepare() error
	Execute() error
	Cleanup() error
}

// RunJob runs a job.
func RunJob(j Job) error {
	UpdateStatus(j, StatusPreparing)
	if err := j.Prepare(); err != nil {
		j.Logger().Println("Job preparation failed:", err)
		j.SetComment(err.Error())
		UpdateStatus(j, StatusFailed)
		return err
	}

	UpdateStatus(j, StatusExecuting)
	if err := j.Execute(); err != nil {
		j.Logger().Println("Job execution failed:", err)
		j.SetComment(err.Error())
		UpdateStatus(j, StatusFailed)
		return err
	}

	UpdateStatus(j, StatusCleanup)
	if err := j.Cleanup(); err != nil {
		j.Logger().Println("Job cleanup failed:", err)
		j.SetComment(err.Error())
		UpdateStatus(j, StatusFailed)
		return err
	}

	UpdateStatus(j, StatusSuccessful)
	return nil
}

// NewJob creates a new job.
func NewJob(data []byte) (Job, error) {
	var r struct {
		Id   int                    `json:"id"`
		Type int                    `json:"type"`
		Data map[string]interface{} `json:"data"`
	}
	if err := json.Unmarshal(data, &r); err != nil {
		return nil, err
	}

	b := JobBase{id: r.Id, logger: newLogger(r.Id)}
	var j Job
	var err error
	switch r.Type {
	case jobTypeReplay:
		j, err = NewReplayJob(b, r.Data)
	default:
		return nil, fmt.Errorf("Unknown job type %d", r.Type)
	}

	return j, err
}

// UpdateStatus updates a job's status.
func UpdateStatus(j Job, status int) {
	j.Logger().Println("Updating status to", status)
	body := map[string]interface{}{
		"worker": WorkerId,
		"job":    j.Id(),
		"status": status,
	}
	if j.Comment() == "" {
		body["comment"] = nil
	} else {
		body["comment"] = j.Comment()
	}
	PostRequest(endpointStatus, body, j.Logger())
}

const (
	endpointStatus = "/status"
	jobTypeReplay  = 0
)

// newLogger creates a new logger.
func newLogger(id int) *log.Logger {
	return log.New(LogWriter, fmt.Sprintf("[Job %d] ", id), log.LstdFlags)
}
