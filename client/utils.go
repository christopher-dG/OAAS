package main

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
)

// Headers adds the necessary headers for the OAAS API.
func Headers(r *http.Request) {
	r.Header.Set("Content-Type", "application/json")
	r.Header.Set("Authorization", Config.ApiKey)
}

// PostRequest sends a POST request to the OAAS API.
func PostRequest(endpoint string, body map[string]interface{}, logger *log.Logger) (*http.Response, error) {
	logger.Println("POSTing to", endpoint)

	b, err := json.Marshal(body)
	if err != nil {
		logger.Println("Couldn't encode request body:", err)
		return nil, err
	}

	req, err := http.NewRequest("POST", Config.ApiUrl+endpoint, bytes.NewReader(b))
	if err != nil {
		logger.Println("Couldn't create request:", err)
		return nil, err
	}
	Headers(req)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		logger.Println("Couldn't send request:", err)
		return nil, err
	}
	if resp.StatusCode >= 400 {
		logger.Println("Bad response code:", resp.StatusCode)
		b, err = ioutil.ReadAll(resp.Body)
		if err == nil && len(b) > 0 {
			logger.Println("Response body:", string(b))
		}
	}

	return resp, nil
}
