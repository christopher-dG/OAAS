package main

import (
	"log"
	"sync"

	"github.com/turnage/graw/reddit"
)

var wg = sync.WaitGroup{}

func main() {
	posts := make(chan reddit.Post)
	doneHTTP := StartHTTP()
	doneMaintenance := StartMaintenance()
	doneReddit, err := StartReddit(posts)
	if err != nil {
		log.Fatal(err)
	}
	doneDiscord, err := StartDiscord(posts)
	if err != nil {
		log.Fatal(err)
	}

	<-doneHTTP
	doneMaintenance <- true
	doneReddit <- true
	doneDiscord <- true
	wg.Wait()
}
