package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
)

// writeJSON writes a text response to the response writer.
func writeText(w http.ResponseWriter, status int, message string) {
	w.WriteHeader(status)
	io.WriteString(w, message)
}

// writeJSON writes a JSON response to the response writer.
func writeJSON(w http.ResponseWriter, status int, content interface{}) {
	b, err := json.Marshal(content)
	if err != nil {
		log.Printf("[json] couldn't encode content '%v': %v\n", content, err)
		writeText(w, 500, "error encoding response")
		return
	}
	w.WriteHeader(status)
	w.Write(b)
}
