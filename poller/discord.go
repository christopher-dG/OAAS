package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/bwmarrin/discordgo"
	"github.com/turnage/graw/reddit"
)

const reaction = "👍"
const nReactions = 3

var (
	dBot         *discordgo.Session
	pendingPosts = make(map[string]reddit.Post)
	dToken       = os.Getenv("DISCORD_TOKEN")
	dChannelID   = os.Getenv("DISCORD_CHANNEL_ID")
	dRoleMention = os.Getenv("DISCORD_ROLE_MENTION")
	apiURL       = os.Getenv("API_URL")

	newPostMsg      = dRoleMention + " :exclamation: New score post :exclamation: Should I upload it? React :+1: to vote yes. I'll upload if we reach " + strconv.Itoa(nReactions) + " reactions (including mine).\n**%s** (post by `/u/%s`) https://redd.it/%s"
	startSuccessMsg = ":+1: Started job. <https://redd.it/%s>"
	startFailureMsg = ":-1: Starting the job failed, maybe try removing and adding a :+1:. <https://redd.it/%s>"
)

// startDiscord starts waiting for posts to upload and starts the
func startDiscord() error {
	if dToken == "" {
		return errors.New("environment variable DISCORD_TOKEN is not set")
	}
	if dChannelID == "" {
		return errors.New("environment variable DISCORD_CHANNEL_ID is not set")
	}
	if dRoleMention == "" {
		return errors.New("environment variable DISCORD_ROLE_MENTION is not set")
	}
	if apiURL == "" {
		return errors.New("environment variable API_URL is not set")
	}

	var err error
	if dBot, err = discordgo.New("Bot " + dToken); err != nil {
		return err
	}
	if _, err = dBot.Channel(dChannelID); err != nil {
		return err
	}

	dBot.AddHandler(handleReaction)
	dBot.AddHandler(handleMessage)

	if err = dBot.Open(); err != nil {
		return err
	}

	go func() {
		for {
			post := <-postChan
			go handlePost(post)
		}
	}()

	return nil
}

// handlePost receives a new Reddit post and prompts Discord users to vote on it.
func handlePost(p reddit.Post) {
	msg, err := sendMsgf(newPostMsg, p.Title, p.Author, p.ID)
	if err != nil {
		return
	}

	pendingPosts[msg.ID] = p

	if err = dBot.MessageReactionAdd(dChannelID, msg.ID, reaction); err != nil {
		log.Println("[discord] couldn't add reaction:", err)
		// Don't return here, it's not a big deal.
	}
}

// handleReactions handles a new reaction being added on a message.
func handleReaction(_ *discordgo.Session, e *discordgo.MessageReactionAdd) {
	if e.ChannelID != dChannelID || e.Emoji.Name != reaction || e.UserID == dBot.State.User.ID {
		return
	}

	found := false
	for p := range pendingPosts {
		if p == e.MessageID {
			found = true
		}
	}
	if !found {
		return
	}

	msg, err := dBot.ChannelMessage(dChannelID, e.MessageID)
	if err != nil {
		log.Println("[discord] couldn't get message:", err)
		return
	}

	for _, r := range msg.Reactions {
		if r.Emoji.Name == reaction && r.Count == nReactions {
			if err = startJob(pendingPosts[e.MessageID]); err != nil {
				log.Println("[discord] starting job failed:", err)
				sendMsgf(startFailureMsg, pendingPosts[e.MessageID].ID)
				return
			}

			sendMsgf(startSuccessMsg, pendingPosts[e.MessageID].ID)
			delete(pendingPosts, e.MessageID)
		}
	}
}

// handleMessage handles an incoming command to the bot.
func handleMessage(_ *discordgo.Session, e *discordgo.MessageCreate) {
	if e.ChannelID != dChannelID || !isMentioned(e.Mentions) {
		return
	}
}

// startJob starts a recording job.
func startJob(p reddit.Post) error {
	job := makeJob(p)
	body, err := json.Marshal(job)
	if err != nil {
		return err
	}

	indented, _ := json.MarshalIndent(job, "", "  ")
	log.Printf("[discord] request body: %s\n", string(indented))

	resp, err := http.Post(apiURL+"/jobs/new", "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}

	if resp.StatusCode != 200 {
		return errors.New("non-200 status code: " + strconv.Itoa(resp.StatusCode))
	}

	log.Println("started job")
	return nil
}

func makeJob(p reddit.Post) map[string]interface{} {
	return map[string]interface{}{
		"id":           p.ID,
		"title":        p.Title,
		"author":       p.Author,
		"domain":       p.Domain,
		"post_time":    p.CreatedUTC,
		"request_time": int64(time.Now().UnixNano() / 1000000),
	}
}
