package main

import (
	"errors"

	"github.com/christopher-dG/go-obs-websocket"
)

const (
	defaultScene = "Replay Farm" // The name of the OBS scene used when recording.
	videoFormat  = ".mp4"        // Video format for exports.
)

var obsClient obsws.Client // The OBS websocket client.

// StartRecording starts recording.
func StartRecording() error {
	if err := maybeInitClient(); err != nil {
		return err
	}

	if resp, err := obsws.NewGetStreamingStatusRequest().SendReceive(obsClient); err != nil {
		return err
	} else if resp.Recording {
		return errors.New("already recording")
	}

	if _, err := obsws.NewStartRecordingRequest().SendReceive(obsClient); err != nil {
		return err
	}

	return nil
}

// StopRecording stops recording.
func StopRecording() error {
	if err := maybeInitClient(); err != nil {
		return err
	}

	if resp, err := obsws.NewGetStreamingStatusRequest().SendReceive(obsClient); err != nil {
		return err
	} else if !resp.Recording {
		return errors.New("not recording")
	}

	_, err := obsws.NewStopRecordingRequest().SendReceive(obsClient)
	return err
}

// SetScene sets the scene to the default.
func SetScene() error {
	if err := maybeInitClient(); err != nil {
		return err
	}

	_, err := obsws.NewSetCurrentSceneRequest(defaultScene).SendReceive(obsClient)
	return err
}

// GetRecordingFolder gets the recording output folder from OBS.
func GetRecordingFolder() (string, error) {
	if err := maybeInitClient(); err != nil {
		return "", err
	}

	resp, err := obsws.NewGetRecordingFolderRequest().SendReceive(obsClient)
	if err != nil {
		return "", err
	}
	return resp.RecFolder, nil
}

// maybeInitClient initializes the OBS client if it isn't already running.
func maybeInitClient() error {
	if obsClient.Connected() {
		return nil
	}
	return obsClient.Connect()
}
