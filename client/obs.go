package main

import obs "github.com/christopher-dG/go-obs-websocket"

func InitObs() error {
	obsClient = obs.Client{
		Host:     "localhost",
		Port:     Config.ObsPort,
		Password: Config.ObsPassword,
	}

	if err := obsClient.Connect(); err != nil {
		return err
	}
	resp, err := obs.NewGetRecordingFolderRequest().SendReceive(obsClient)
	if err != nil {
		return err
	}
	obsFolder = resp.RecFolder

	return nil
}

func CleanupObs() {
	obsClient.Disconnect()
}

// StartRecording starts recording.
func StartRecording() error {
	_, err := obs.NewStartRecordingRequest().SendReceive(obsClient)
	return err
}

// StopRecording stops recording.
func StopRecording() error {
	_, err := obs.NewStopRecordingRequest().SendReceive(obsClient)
	return err
}

var (
	obsClient obs.Client
	obsFolder string
)
