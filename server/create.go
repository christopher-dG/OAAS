package main

import (
	"math/rand"
	"net/http"
	"strconv"

	"github.com/turnage/graw/reddit"
)

func init() { http.HandleFunc("/create", create) }

func create(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	posts <- reddit.Post{
		ID:     strconv.Itoa(rand.Intn(10000)),
		Title:  "test job",
		Author: " test job",
	}
	w.WriteHeader(200)
}
