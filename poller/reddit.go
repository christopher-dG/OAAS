package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"regexp"

	"github.com/turnage/graw"
	"github.com/turnage/graw/reddit"
)

const subreddit = "osugame"

var (
	rBot       reddit.Bot
	titleRE    = regexp.MustCompile(`.+\|.+-.+\[.+\]`)
	rConfig    = graw.Config{Subreddits: []string{subreddit}}
	rBotConfig = reddit.BotConfig{
		Agent: os.Getenv("REDDIT_USER_AGENT"),
		App: reddit.App{
			ID:       os.Getenv("REDDIT_CLIENT_ID"),
			Secret:   os.Getenv("REDDIT_CLIENT_SECRET"),
			Username: os.Getenv("REDDIT_USERNAME"),
			Password: os.Getenv("REDDIT_PASSWORD"),
		},
	}

	commentMsg = "Video of this play! :)\nhttps://youtu.be/%s"
)

// startReddit starts polling a subreddit and handles each new post.
func startReddit() (chan error, error) {
	if rBotConfig.Agent == "" {
		return nil, errors.New("environment variable REDDIT_USER_AGENT is not set")
	}
	if rBotConfig.App.ID == "" {
		return nil, errors.New("environment variable REDDIT_CLIENT_ID is not set")
	}
	if rBotConfig.App.Secret == "" {
		return nil, errors.New("environment variable REDDIT_CLIENT_SECRET is not set")
	}
	if rBotConfig.App.Username == "" {
		return nil, errors.New("environment variable REDDIT_USERNAME is not set")
	}
	if rBotConfig.App.Password == "" {
		return nil, errors.New("environment variable REDDIT_PASSWORD is not set")
	}

	var err error
	if rBot, err = reddit.NewBot(rBotConfig); err != nil {
		return nil, err
	}

	_, wait, err := graw.Run(&postHandler{}, rBot, rConfig)
	if err != nil {
		return nil, err
	}

	// TODO: Delete me.
	go func() { postChan <- reddit.Post{ID: "96979n", Title: "title here", Author: "author_here"} }()

	done := make(chan error)
	go func() { done <- wait() }()
	return done, nil
}

// PostHandler receives new post events and handles them.
type postHandler struct{}

// Post is called on all new Reddit posts. If it returns non-nil, the bot goes down.
func (ph *postHandler) Post(p *reddit.Post) error {
	if titleRE.MatchString(p.Title) {
		log.Println("[reddit] post matches:", p.Title)
		postChan <- *p
	}
	return nil
}

// Reply replies to a Reddit post with a YouTube link.
func Reply(p reddit.Post, ytID string) error {
	return rBot.Reply(p.Name, fmt.Sprintf(commentMsg, ytID))
}
