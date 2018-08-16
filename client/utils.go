package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
)

// httpGet makes a GET request and returns the body.
func httpGet(url string) ([]byte, error) {
	httpLogger.Println("GET:", url)
	resp, err := http.Get(url)
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
