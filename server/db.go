package main

import (
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

const schema = `
create table if not exists workers(
  id text primary key,
  last_poll timestamptz not null
);

create table if not exists jobs(
  id text primary key,
  worker_id text references workers(id) on delete set null,
  status integer not null,
  comment text,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

alter table workers add column if not exists current_job_id text references jobs(id) on delete set null;
`

const (
	_                  = iota
	statusBacklogged   // Backlogged: waiting for workers to free up.
	statusAssigned     // Assigned to the worker, but the worker hasn't received it yet.
	statusPending      // Received by the worker.
	statusAcknowledged // Acknowledged by the worker.
	statusRecording    // The worker has begun recording.
	statusUploading    // The worker has begun uploading.
	statusSuccessful   // Job finished and successful.
	statusFailed       // Job finished and failed.
)

var db = func() *sqlx.DB {
	d := sqlx.MustConnect("postgres", "sslmode=disable")
	d.MustExec(schema)
	return d
}()
