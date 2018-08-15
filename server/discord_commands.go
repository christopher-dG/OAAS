package main

import (
	"log"
	"time"

	"replay-bot/shared"

	"github.com/apcera/termtables"
)

const dbErrMsg = ":-1: Database error."

// CmdListActive lists all active jobs.
func CmdListActive() {
	jobs, err := GetActiveJobs()
	if err != nil {
		sendMsg(":-1: Database error.")
		return
	}
	cmdListJobs(jobs)
}

// CmdListBacklog lists all backlogged job.
func CmdListBacklog() {
	jobs, err := GetBacklog()
	if err != nil {
		sendMsg(":-1: Database error.")
		return
	}
	cmdListJobs(jobs)
}

// cmdListJobs formats jobs into a table and sends it to the Discord channel.
func cmdListJobs(jobs []*Job) {
	if len(jobs) == 0 {
		sendMsg("No jobs.")
		return
	}
	table := termtables.CreateTable()
	table.AddHeaders("Job", "Worker", "Status", "Created", "Updated")
	for _, j := range jobs {
		var worker string
		if j.WorkerID.Valid {
			worker = j.WorkerID.String
		} else {
			worker = "none"
		}
		table.AddRow(
			j.ID,
			worker,
			shared.StatusStr[j.Status],
			time.Since(j.CreatedAt),
			time.Since(j.UpdatedAt),
		)
	}
	sendMsgf("```\n%s\n```", table.Render())
}

// CmdListOnlineWorkers lists online workers.
func CmdListOnlineWorkers() {
	workers, err := GetWorkers()
	if err != nil {
		log.Println("[>get workers] couldn't get available workers:", err)
		sendMsg(dbErrMsg)
		return
	}
	online := []*Worker{}
	for _, w := range workers {
		if w.Online() {
			online = append(online, w)
		}
	}
	cmdListWorkers(online)
}

// CmdListAllWorkers lists all workers.
func CmdListAllWorkers() {
	workers, err := GetWorkers()
	if err != nil {
		log.Println("[>get workers] couldn't get available workers:", err)
		sendMsg(dbErrMsg)
		return
	}
	cmdListWorkers(workers)
}

func cmdListWorkers(workers []*Worker) {
	if len(workers) == 0 {
		sendMsg("No workers.")
		return
	}
	table := termtables.CreateTable()
	table.AddHeaders("Worker", "Job", "Last activity")
	for _, w := range workers {
		var job string
		if w.CurrentJobID.Valid {
			job = w.CurrentJobID.String
		} else {
			job = "none"
		}
		table.AddRow(w.ID, job, time.Since(w.LastPoll))
	}
	sendMsgf("```\n%s\n```", table.Render())
}
