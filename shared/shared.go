package shared

const (
	_                  = iota
	StatusBacklogged   // Backlogged: waiting for workers to free up.
	StatusAssigned     // Assigned to the worker, but the worker hasn't received it yet.
	StatusPending      // Received by the worker.
	StatusAcknowledged // Acknowledged by the worker.
	StatusRecording    // The worker has begun recording.
	StatusUploading    // The worker has begun uploading.
	StatusSuccessful   // Job finished and successful.
	StatusFailed       // Job finished and failed.
)

var StatusStr = map[int]string{
	StatusBacklogged:   "backlogged",
	StatusAssigned:     "assigned",
	StatusPending:      "pending",
	StatusAcknowledged: "acknowledged",
	StatusRecording:    "recording",
	StatusUploading:    "uploading",
	StatusSuccessful:   "successful",
	StatusFailed:       "failed",
}

// Job is a replay recording and uploading job.
type Job struct {
	ID     string `db:"id" json:"id"`         // Reddit ID of the post the job corresponds to.
	Title  string `db:"title" json:"title"`   // Reddit post title.
	Author string `db:"author" json:"author"` // Reddit author username.
}
