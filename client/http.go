package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

var httpClient = http.Client{Timeout: time.Second * 10}

// headers adds the necessary headers for the Replay Farm API.
func headers(r *http.Request) {
	r.Header.Set("Content-Type", "application/json")
	r.Header.Set("Authorization", config.ApiKey)
}

// postRF makes a POST request to the Replay Farm API.
func postRF(path string, body interface{}) (*http.Response, error) {
	b, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest(http.MethodPost, config.ApiURL+path, bytes.NewBuffer(b))
	if err != nil {
		return nil, err
	}
	headers(req)

	return httpClient.Do(req)
}

// getBody makes a GET request and returns the body.
func getBody(url string) ([]byte, error) {
	log.Println("GET:", url)
	resp, err := httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("non-200 status code %d", resp.StatusCode)
	}
	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return b, nil
}
