package main

import (
	"fmt"
	"log"

	"github.com/bwmarrin/discordgo"
)

// isMentioned checks if the bot is mentioned in a message.
func isMentioned(mentions []*discordgo.User) bool {
	for _, m := range mentions {
		if m.ID == dBot.State.User.ID {
			return true
		}
	}
	return false
}

// sendMsg sends a Discord message.
func sendMsg(text string) (*discordgo.Message, error) {
	msg, err := dBot.ChannelMessageSend(dChannelID, text)
	if err != nil {
		log.Println("[discord] couldn't send message:", err)
		return nil, err
	}
	log.Println("[discord] sent message:", msg.Content)
	return msg, nil
}

// sendMsgf sends a formatted Discord message.
func sendMsgf(text string, args ...interface{}) (*discordgo.Message, error) {
	return sendMsg(fmt.Sprintf(text, args...))
}
