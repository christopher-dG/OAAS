package main

const (
	// StatusRecording indicates that the replay is being recorded.
	StatusRecording = iota
	// StatusUploading indicates that the replay is being uploaded.
	StatusUploading
	// StatusSuccessful indicates that the job is finished and successful.
	StatusSuccessful
	// StatusSuccessful indicates that the job is finished but failed.
	StatusFailed
)

var StatusMap = map[int]string{
	StatusRecording:  "recording",
	StatusUploading:  "uploading",
	StatusSuccessful: "successful",
	StatusFailed:     "failed",
}
