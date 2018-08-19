package main

import (
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

const schema = `
create table if not exists workers(
  id text primary key,
  last_poll timestamptz not null,
  last_job timestampz
);

create table if not exists jobs(
  id text primary key,
  title text not null,
  author text not null,
  worker_id text references workers(id) on delete set null,
  status integer not null,
  comment text,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

alter table workers add column if not exists current_job_id text references jobs(id) on delete set null;

create table if not exists keys(
  key text primary key
);

`

var db = func() *sqlx.DB {
	d := sqlx.MustConnect("postgres", "sslmode=disable")
	d.MustExec(schema)
	return d
}()
