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
func StartReddit(posts chan reddit.Post) (chan bool, error) {
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

	log.Println("[reddit] starting Reddit poller for subreddit", subreddit)
	stop, _, err := graw.Run(&PostHandler{Posts: posts}, rBot, rConfig)
	if err != nil {
		return nil, err
	}

	done := make(chan bool)
	go func() {
		<-done
		stop()
	}()
	return done, nil
}

// PostHandler receives new post events and handles them.
type PostHandler struct {
	Posts chan reddit.Post
}

// Post is called on all new Reddit posts. If it returns non-nil, the bot goes down.
func (ph *PostHandler) Post(p *reddit.Post) error {
	wg.Add(1)
	if titleRE.MatchString(p.Title) {
		log.Println("[reddit] post matches:", p.Title)
		ph.Posts <- *p
	}
	wg.Done()
	return nil
}

// RedditReply replies to a Reddit post with a YouTube link.
func RedditReply(p reddit.Post, ytID string) error {
	return rBot.Reply(p.Name, fmt.Sprintf(commentMsg, ytID))
}
