package main

import (
	"bytes"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"strconv"
	"time"

	"replay-bot/shared"

	osuapi "github.com/thehowl/go-osuapi"
)

const (
	pollRoute   = "/poll"
	statusRoute = "/jobs/status"
	interval    = time.Second * 10
)

var (
	httpLogger = log.New(os.Stdout, "[http] ", log.LstdFlags)
	pollLogger = log.New(os.Stdout, "[/poll] ", log.LstdFlags)
	apiURL     = os.Getenv("REPLAY_BOT_API_URL")
	apiKey     = os.Getenv("REPLAY_BOT_API_KEY")
	jobs       = make(chan shared.Job)
	httpClient = http.Client{Timeout: time.Second * 3}

	username = func() string {
		usr, err := user.Current()
		if err != nil {
			log.Fatal(err)
		}
		return usr.Username
	}()
	id = func() string {
		path := filepath.Join(osuRoot, "replay-bot-token")
		token, err := ioutil.ReadFile(path)
		if err != nil {
			token = []byte(fmt.Sprintf("%x", md5.Sum([]byte(strconv.Itoa(int(time.Now().Unix()))))))[:4]
			ioutil.WriteFile(path, token, 0644)
		}
		return fmt.Sprintf("%s-%s", username, string(token))
	}()
	pollReq = func() *http.Request {
		b := []byte(fmt.Sprintf(`{"worker":"%s"}`, id))
		req, err := http.NewRequest(http.MethodPost, apiURL+pollRoute, bytes.NewBuffer(b))
		if err != nil {
			log.Fatal(err)
		}
		req.Header.Set("Authorization", apiKey)
		return req
	}()
)

// JobContext contains the data required to complete a job.
type JobContext struct {
	Job     shared.Job
	Player  *osuapi.User
	Beatmap *osuapi.Beatmap
}

func main() {
	if apiURL == "" {
		log.Fatal("environment variable REPLAY_BOT_API_URL is not set")
	}
	if apiKey == "" {
		log.Fatal("environment variable REPLAY_BOT_API_KEY is not set")
	}
	if osuRoot == "" {
		log.Fatal("environment variable REPLAY_BOT_SKINS_DIR is not set")
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
	resp, err := httpClient.Do(pollReq)
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
	log.SetPrefix(fmt.Sprintf("[job %s] ", j.ID))
	log.Println("starting job")

	// TODO: Think about how easily we want to give up.
	var err error

	if err = updateStatus(j, shared.StatusAcknowledged, ""); err != nil {
		fail(j, "error updating status", err)
		return
	}

	log.Println("preparing job")
	ctx, err := prepare(j)
	if err != nil {
		fail(j, "error preparing job", err)
		return
	}

	if err = updateStatus(j, shared.StatusRecording, ""); err != nil {
		fail(j, "error updating status -> recording", err)
		return
	}

	log.Println("starting recording")
	if err = ctx.startRecording(); err != nil {
		fail(j, "error starting recording", err)
		return
	}

	log.Println("starting replay")
	var done chan bool
	if done, err = ctx.startReplay(); err != nil {
		fail(j, "error starting replay", err)
		return
	}

	log.Println("waiting for replay to end")
	<-done

	log.Println("stopping recording")
	var path string
	if path, err = ctx.stopRecording(); err != nil {
		fail(j, "error stopping recording", err)
		return
	}

	if err = updateStatus(j, shared.StatusUploading, ""); err != nil {
		fail(j, "error updating status", err)
		return
	}

	log.Println("uploading video at", path)
	var url string
	if url, err = ctx.uploadVideo(path); err != nil {
		fail(j, "error uploading video", err)
		return
	}

	if err = updateStatus(j, shared.StatusSuccessful, url); err != nil {
		fail(j, "error updating status", err)
		return
	}
}

// startRecording starts recording.
func (ctx *JobContext) startRecording() error {
	return nil
}

// startReplay starts the replay and returns a channel to block until it's done.
func (ctx *JobContext) startReplay() (chan bool, error) {
	done := make(chan bool)

	return done, nil
}

// stopRecording stops recording and returns the path of the exported video.
func (ctx *JobContext) stopRecording() (string, error) {
	return "TODO", nil
}

// uploadVideo uploads the video at path to YouTube and returns the URL.
func (ctx *JobContext) uploadVideo(path string) (string, error) {
	return "TODO", nil
}

// updateStatus sends a request to /jobs/status updating the job status.
func updateStatus(j shared.Job, status int, comment string) error {
	log.Println("updating status ->", shared.StatusStr[status])
	_, err := postJobsStatus(map[string]interface{}{
		"worker":  id,
		"job":     j.ID,
		"status":  status,
		"comment": comment,
	})
	return err
}

// fail updates the job status to FAILED.
func fail(j shared.Job, context string, err error) {
	comment := fmt.Sprintf("%s: %v", context, err)
	log.Println(comment)
	updateStatus(j, shared.StatusFailed, comment)
}

// postJobsStatus makes an HTTP POST request to the API's /jobs/status endpoint.
func postJobsStatus(body map[string]interface{}) (*http.Response, error) {
	httpLogger.Println("POST:", statusRoute)
	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	httpLogger.Println("request body:", string(b))
	req, err := http.NewRequest(http.MethodPost, apiURL+statusRoute, bytes.NewBuffer(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", apiKey)
	resp, err := httpClient.Do(req)
	if err == nil {
		httpLogger.Println("status code:", resp.StatusCode)
	}
	return resp, err
}
