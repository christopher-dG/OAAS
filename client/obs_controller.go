package main

import (
	obs "github.com/christopher-dG/go-obs-websocket"
)

// StartRecording starts recording.
func StartRecording() error {
	// Stop recording, just in case.
	obs.NewGetStreamingStatusRequest().SendReceive(obsClient)
	_, err := obs.NewStartRecordingRequest().SendReceive(obsClient)
	return err
}

// StopRecording stops recording.
func StopRecording() error {
	_, err := obs.NewStopRecordingRequest().SendReceive(obsClient)
	return err
}

// GetRecordingFolder gets the recording output folder from OBS.
func GetRecordingFolder() (string, error) {
	resp, err := obs.NewGetRecordingFolderRequest().SendReceive(obsClient)
	if err != nil {
		return "", err
	}
	return resp.RecFolder, nil
}
