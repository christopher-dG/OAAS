package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/user"
	"strconv"
	"time"

	"replay-bot/shared"
)

const (
	pollRoute   = "/poll"
	statusRoute = "/jobs/status"
	interval    = time.Second * 10
)

var (
	httpLogger = log.New(os.Stdout, "[http] ", log.LstdFlags)
	pollLogger = log.New(os.Stdout, "[/poll] ", log.LstdFlags)
	jobLogger  = log.New(os.Stdout, "", log.LstdFlags)
	jobs       = make(chan shared.Job)
	apiURL     = os.Getenv("REPLAY_BOT_API_URL")
	id         = func() string {
		usr, err := user.Current()
		if err != nil {
			return strconv.Itoa(int(time.Now().Unix()))
		}
		return usr.Username // TODO: Needs more uniqueness.
	}()
)

// JobContext contains the data required to complete a job.
type JobContext struct {
	Job shared.Job
}

func main() {
	if apiURL == "" {
		log.Fatal("environment variable REPLAY_BOT_API_URL is not set")
	}

	log.Println("Worker ID:", id)
	go poll()
	for {
		j := <-jobs
		go process(j)
	}
}

// poll calls the /poll endpoint to register presence and check for new work.
func poll() {
	for {
		pollOnce()
		time.Sleep(interval)
	}
}

func pollOnce() {
	resp, err := httpPOST(pollRoute, map[string]string{"worker": id})
	if err != nil {
		pollLogger.Println("error making request:", err)
		return
	}
	if resp.StatusCode != 200 && resp.StatusCode != 204 {
		pollLogger.Println("unexpected status code:", strconv.Itoa(resp.StatusCode))
		return
	}

	if resp.StatusCode == 204 {
		pollLogger.Println("no new job")
		return
	}

	defer resp.Body.Close()
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		pollLogger.Println("couldn't read response body:", err)
		return
	}

	var j shared.Job
	if err = json.Unmarshal(respBody, &j); err != nil {
		pollLogger.Println("couldn't decode response body:", err)
		return
	}

	jobs <- j
}

// process processes a job.
func process(j shared.Job) {
	jobLogger.SetPrefix(fmt.Sprintf("[%s] ", j.ID))
	jobLogger.Println("starting job")

	// TODO: Think about how easily we want to give up.
	var err error

	if err = updateStatus(j, shared.StatusAcknowledged, ""); err != nil {
		fail(j, "error updating status", err)
		return
	}

	jobLogger.Println("preparing job")
	var ctx JobContext
	if ctx, err = prepare(j); err != nil {
		fail(j, "error preparing job", err)
		return
	}

	if err = updateStatus(j, shared.StatusRecording, ""); err != nil {
		log.Println("[update-status-recording]", err)
		fail(j, "error updating status -> recording", err)
		return
	}

	jobLogger.Println("starting recording")
	if err = startRecording(ctx); err != nil {
		fail(j, "error starting recording", err)
		return
	}

	jobLogger.Println("starting replay")
	var done chan bool
	if done, err = startReplay(ctx); err != nil {
		fail(j, "error starting replay", err)
		return
	}

	jobLogger.Println("waiting for replay to end")
	<-done
	jobLogger.Println("replay finished")

	jobLogger.Println("stopping recording")
	var path string
	if path, err = stopRecording(ctx); err != nil {
		fail(j, "error stopping recording", err)
		return
	}

	if err = updateStatus(j, shared.StatusUploading, ""); err != nil {
		fail(j, "error updating status", err)
		return
	}

	jobLogger.Println("uploading video at", path)
	var url string
	if url, err = uploadVideo(ctx, path); err != nil {
		fail(j, "error uploading video", err)
		return
	}

	if err = updateStatus(j, shared.StatusSuccessful, url); err != nil {
		fail(j, "error updating status", err)
		return
	}
}

// prepare prepares a job.
func prepare(j shared.Job) (JobContext, error) {
	return JobContext{Job: j}, nil
}

// startRecording starts recording.
func startRecording(ctx JobContext) error {
	return nil
}

// startReplay starts the replay and returns a channel to block until it's done.
func startReplay(ctx JobContext) (chan bool, error) {
	done := make(chan bool)

	return done, nil
}

// stopRecording stops recording and returns the path of the exported video.
func stopRecording(ctx JobContext) (string, error) {
	return "TODO", nil
}

// uploadVideo uploads the video at path to YouTube and returns the URL.
func uploadVideo(ctx JobContext, path string) (string, error) {
	return "TODO", nil
}

// updateStatus sends a request to /jobs/status updating the job status.
func updateStatus(j shared.Job, status int, comment string) error {
	jobLogger.Println("updating status ->", shared.StatusStr[status])
	body := map[string]interface{}{
		"worker":  id,
		"job":     j.ID,
		"status":  status,
		"comment": comment,
	}
	_, err := httpPOST(statusRoute, body)
	return err
}

// fail updates the job status to FAILED.
func fail(j shared.Job, context string, err error) {
	comment := fmt.Sprintf("%s: %v", context, err)
	jobLogger.Println(comment)
	updateStatus(j, shared.StatusFailed, comment)
}

// httpPOST makes an HTTP POST request to the API.
func httpPOST(route string, body interface{}) (*http.Response, error) {
	httpLogger.Println("request destination:", apiURL+route)
	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	httpLogger.Println("request body:", string(b))
	resp, err := http.Post(apiURL+route, "application/json", bytes.NewBuffer(b))
	if err == nil {
		httpLogger.Println("status code:", resp.StatusCode)
	}
	return resp, err
}
