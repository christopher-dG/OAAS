package main

import (
	"log"
	"sync"

	"github.com/turnage/graw/reddit"
)

var (
	wg    = sync.WaitGroup{}
	posts = make(chan reddit.Post)
)

func main() {
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
