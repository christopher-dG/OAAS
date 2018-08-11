package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/user"
	"strconv"
	"time"
)

const (
	pollRoute   = "/poll"
	statusRoute = "/jobs/status"
	interval    = time.Second * 10
)

var (
	jobs     = make(chan job)
	apiURL   = os.Getenv("API_URL")
	statuses = map[string]int{
		"ACKNOWLEDGED": 1,
		"RECORDING":    2,
		"UPLOADING":    3,
		"SUCCEEDED":    4,
		"FAILED":       5,
	}
	id = func() string {
		usr, err := user.Current()
		if err != nil {
			return strconv.Itoa(int(time.Now().Unix()))
		}
		return usr.Username // TODO: Needs more uniqueness.
	}()
)

type job map[string]interface{}

func main() {
	if apiURL == "" {
		log.Fatal("environment variable API_URL is not set")
	}

	log.Println("ID:", id)
	go poll()
	for {
		j := <-jobs
		go j.process()
	}
}

// poll calls the /poll endpoint to register presence and check for new work.
func poll() {
	for {
		time.Sleep(interval)

		resp, err := httpPOST(pollRoute, map[string]string{"worker": id})
		if err != nil {
			log.Println("[/poll]", err)
			continue
		}
		if resp.StatusCode != 200 && resp.StatusCode != 204 {
			log.Println("[/poll] unexpected status code:", strconv.Itoa(resp.StatusCode))
			continue
		}

		if resp.StatusCode == 204 {
			continue
		}

		defer resp.Body.Close()
		respBody, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Println("[/poll] couldn't read response body:", err)
			continue
		}

		var j job
		if err = json.Unmarshal(respBody, &j); err != nil {
			log.Println("[/poll] couldn't decode response body:", err)
			continue
		}

		jobs <- j
	}
}

// processJob processes a job.
func (j job) process() {
	log.Println("processing job:", j["id"])

	// TODO: Think about how easily we want to give up.
	var err error

	log.Println("updating status -> acknowledged")
	if err = updateStatus(statuses["ACKNOWLEDGED"]); err != nil {
		log.Println("[update-status-acknowledged]", err)
		fail()
		return
	}
	log.Println("updated status")

	log.Println("preparing job")
	if err = j.prepare(); err != nil {
		log.Println("[job-prepare]", err)
		fail()
		return
	}
	log.Println("prepared job")

	log.Println("updating status -> recording")
	if err = updateStatus(statuses["RECORDING"]); err != nil {
		log.Println("[update-status-recording]", err)
		fail()
		return
	}
	log.Println("updated status")

	log.Println("starting recording")
	if err = j.startRecording(); err != nil {
		log.Println("[job-start-recording]", err)
		fail()
		return
	}
	log.Println("tstarted recording")

	log.Println("starting replay")
	var done chan bool
	if done, err = j.startReplay(); err != nil {
		log.Println("[job-start-replay]", err)
		fail()
		return
	}
	log.Println("started replay")

	log.Println("waiting for replay to finish")
	<-done
	log.Println("replay finished")

	log.Println("stopping recording")
	var path string
	if path, err = j.stopRecording(); err != nil {
		log.Println("[job-stop-recording]", err)
		fail()
		return
	}
	log.Println("stopped recording")

	log.Println("updating status -> uploading")
	if err = updateStatus(statuses["UPLOADING"]); err != nil {
		log.Println("[update-status-uploading]", err)
		fail()
		return
	}

	log.Println("uploading video at", path)
	var url string
	if url, err = j.uploadVideo(path); err != nil {
		log.Println("[job-upload-video]", err)
		fail()
		return
	}
	log.Println("uploaded video:", url)

	log.Println("updating status -> succeeded")
	if err = succeed(url); err != nil {
		log.Println("[update-status-succeeded]", err)
		fail()
		return
	}
	log.Println("updated status")
}

// prepare prepares the job.
func (j job) prepare() error {
	return nil
}

// startRecording starts recording.
func (j job) startRecording() error {
	return nil
}

// startReplay starts the replay and returns a channel to block until it's done.
func (j job) startReplay() (chan bool, error) {
	done := make(chan bool)

	return done, nil
}

// stopRecording stops recording and returns the path of the exported video.
func (j job) stopRecording() (string, error) {
	return "TODO", nil
}

// uploadVideo uploads the video at path to YouTube and returns the URL.
func (j job) uploadVideo(path string) (string, error) {
	return "TODO", nil
}

// updateStatus sends a request to /jobs/status updating the job status.
func updateStatus(status int) error {
	_, err := httpPOST(statusRoute, map[string]interface{}{"worker": id, "status": status})
	return err
}

// succeed updates the job status to SUCCEEDED.
func succeed(url string) error {
	body := map[string]interface{}{
		"worker": id,
		"status": statuses["SUCCEEDED"],
		"url":    url,
	}
	_, err := httpPOST(statusRoute, body)
	return err
}

// fail updates the job status to FAILED.
func fail() error {
	log.Println("updating status -> failed")
	err := updateStatus(statuses["FAILED"])
	if err != nil {
		log.Println("[update-status-failed]", err)
		return err
	}
	log.Println("updated status")
	return nil

}

// httpPOST makes an HTTP POST request to the API.
func httpPOST(route string, body interface{}) (*http.Response, error) {
	log.Println("request destination", route)
	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	log.Println("request body:", string(b))
	resp, err := http.Post(apiURL+route, "application/json", bytes.NewBuffer(b))
	if err == nil {
		log.Println("status code:", resp.StatusCode)
	}
	return resp, err
}
