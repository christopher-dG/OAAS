package main

import (
	"fmt"
	"log"
	"path/filepath"
)

const statusRoute = "/status" // Endpoint to update job status.

// Job is a recording/uploading job to be completed by the worker.
type Job struct {
	ID     int `json:"id"` // Job ID.
	Player struct {
		UserID   int    `json:"user_id"`  // Player ID.
		Username string `json:"username"` // Player name.
	} `json:"player"`
	Beatmap struct {
		BeatmapID    int    `json:"beatmap_id"`    // Beatmap ID.
		BeatmapsetID int    `json:"beatmapset_id"` // Mapset ID.
		Artist       string `json:"artist"`        // Song artist.
		Title        string `json:"title"`         // Song title.
		Version      string `json:"version"`       // Diff name.
		MaxCombo     int    `json:"max_combo"`     // Maximum combo.
	} `json:"beatmap"` // Beatmap played.
	Score struct {
		Mods     int     `json:"mods"`     // Enabled mods (bitwise OR).
		Accuracy float64 `json:"accuracy"` // Accuracy of the play (0-100).
		PP       float64 `json:"pp"`       // pp earned.
		Combo    int     `json:"combo"`    // Maximum combo achieved.
		NMiss    int     `json:"nmiss"`    // Number of misses.
	} `json:"score"`
	Mode   int    `json:"mode"`   // Game mode.
	Replay string `json:"replay"` // Base64-encoded replay file.
	Skin   *struct {
		Name string `json:"name"` // Skin name.
		URL  string `json:"url"`  // Skin download URL.
	} `json:"skin"` // Skin to use (empty if default).
}

// Process processes the job from start to finish.
func (j Job) Process() {
	log.SetPrefix(fmt.Sprintf("[job %d] ", j.ID))
	log.Println("starting job")

	if err := j.Prepare(); err != nil {
		j.fail("preparation failed", err)
		return
	}

	if err := j.updateStatus(StatusRecording, nil); err != nil {
		log.Println("updating status failed:", err)
	}

	if err := j.Record(); err != nil {
		j.fail("recording failed", err)
		return
	}

	if err := j.updateStatus(StatusUploading, nil); err != nil {
		log.Println("updating status failed:", err)
	}

	if err := j.Upload(); err != nil {
		j.fail("uploading failed", err)
		return
	}

	if err := j.updateStatus(StatusSuccessful, nil); err != nil {
		log.Println("updating status failed:", err)
	}
}

// replayPath gets the path to the job's replay file (the file is not guaranteed to exist).
func (j Job) replayPath() string {
	return filepath.Join(localDir, "osr", fmt.Sprintf("%d.osr", j.ID))
}

// updateStatus updates the job's status.
func (j Job) updateStatus(status int, comment *string) error {
	log.Println("updating status ->", StatusMap[status])

	resp, err := postRF(statusRoute, map[string]interface{}{
		"worker":  workerID,
		"job":     j.ID,
		"status":  status,
		"comment": comment,
	})
	if err != nil {
		return err
	}

	if resp.StatusCode != 204 {
		return fmt.Errorf("non-204 status code: %d", resp.StatusCode)
	}
	return nil
}

// fail updates the job status to FAILED.
func (j Job) fail(context string, err error) {
	var comment string
	if context != "" && err != nil {
		comment = fmt.Sprintf("%s: %v", context, err)
	} else if context != "" {
		comment = context
	} else if err != nil {
		comment = err.Error()
	}

	if comment != "" {
		log.Println(comment)
		j.updateStatus(StatusFailed, &comment)
	} else {
		j.updateStatus(StatusFailed, nil)
	}
}
