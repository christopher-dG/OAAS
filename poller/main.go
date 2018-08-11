package main

import (
	"log"

	"github.com/turnage/graw/reddit"
)

var postChan = make(chan reddit.Post)

func main() {
	redditDone, err := startReddit()
	if err != nil {
		log.Fatal("[reddit] couldn't initialize: ", err)
	}

	if err = startDiscord(); err != nil {
		log.Fatal("[discord] couldn't initialize: ", err)
	}

	for {
		select {
		case err := <-redditDone:
			log.Fatal("[reddit] monitor failed: ", err)
		}
	}
}
