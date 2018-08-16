package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"replay-bot/shared"

	"github.com/mholt/archiver"
	osuapi "github.com/thehowl/go-osuapi"
)

const (
	defaultSkin = "replay-bot-default"
	skinsAPI    = "https://circle-people.com/skins-api.php?player="
)

var (
	osuRoot   = os.Getenv("REPLAY_BOT_OSU_ROOT")
	skinsDir  = filepath.Join(osuRoot, "Skins")
	mapsDir   = filepath.Join(osuRoot, "Songs")
	osuCfg    = filepath.Join(osuRoot, fmt.Sprintf("osu.%s.cfg", username))
	apiKey    = os.Getenv("REPLAY_BOT_OSU_API_KEY")
	apiClient = osuapi.NewClient(apiKey)
)

// prepare prepares the job and creates a JobContext.
func prepare(j shared.Job) (*JobContext, error) {
	player, err := getPlayer(j.Title)
	if err != nil {
		return nil, err
	}

	beatmap, err := getBeatmap(j.Title, player)
	if err != nil {
		return nil, err
	}

	if err = downloadMapset(beatmap.BeatmapSetID); err != nil {
		return nil, err
	}

	installSkin(getSkin(player.Username))

	return &JobContext{
		Job: j,
		// Player:  player,
		Beatmap: beatmap,
	}, nil
}

// getPlayer finds the player referenced in the post title.
func getPlayer(title string) (*osuapi.User, error) {
	tokens := strings.Split(title, "|")
	if len(tokens) == 1 {
		return nil, errors.New("invalid title")
	}
	name := strings.TrimSpace(tokens[0])
	return apiClient.GetUser(osuapi.GetUserOpts{Username: name, EventDays: 31})
}

// getBeatmap finds the beatmap referenced in the post title.
func getBeatmap(title string, user *osuapi.User) (*osuapi.Beatmap, error) {
	re := regexp.MustCompile(`\|.+-.+?\[.+?\]`)
	mapStr := re.FindString(title)
	if mapStr == "" {
		return nil, errors.New("no beatmap regex match")
	}
	mapStr = strings.ToLower(strings.TrimSpace(mapStr[1:])) // Remove the leading '|'.
	log.Println("searching for beatmap:", mapStr)

	for _, e := range user.Events {
		if strings.Contains(strings.ToLower(e.DisplayHTML), mapStr) {
			opts := osuapi.GetBeatmapsOpts{BeatmapID: e.BeatmapID}
			beatmaps, err := apiClient.GetBeatmaps(opts)
			if err != nil {
				continue
			}
			if len(beatmaps) == 0 {
				continue
			}
			return &beatmaps[0], nil
		}
	}

	opts := osuapi.GetUserScoresOpts{UserID: user.UserID, Limit: 50}
	scores, err := apiClient.GetUserBest(opts)
	if err != nil {
		return nil, errors.New("beatmap not found")
	}

	for _, s := range scores {
		opts := osuapi.GetBeatmapsOpts{BeatmapID: s.BeatmapID}
		beatmaps, err := apiClient.GetBeatmaps(opts)
		if err != nil {
			continue
		}
		if len(beatmaps) == 0 {
			continue
		}
		b := beatmaps[0]
		str := strings.ToLower(fmt.Sprintf("%s - %s [%s]", b.Artist, b.Title, b.DiffName))
		if str == mapStr {
			return &b, nil
		}
	}

	return nil, errors.New("beatmap not found")
}

// setupSkin downloads the
func getSkin(player string) string {
	b, err := httpGet(skinsAPI + player)
	if err != nil {
		log.Println("request to skins API failed:", err)
		return defaultSkin
	}

	if len(b) == 0 {
		log.Println("no skin available for", player)
		return defaultSkin
	}

	s := string(b)
	skinName := path.Base(s[:len(s)-len(path.Ext(s))])

	skinPath := filepath.Join(skinsDir, skinName)
	if f, err := os.Stat(skinPath); err == nil && f.IsDir() {
		log.Println("found existing skin", skinName)
		return skinName
	}

	if b, err = httpGet(string(b)); err != nil {
		log.Printf("request to %s failed: %v\n", string(b), err)
		return defaultSkin
	}

	zipPath := filepath.Join(os.TempDir(), skinName+".zip")
	if err = ioutil.WriteFile(zipPath, b, os.ModePerm); err != nil {
		log.Println("saving skin failed:", err)
		return defaultSkin
	}

	if err = archiver.Zip.Open(zipPath, skinPath); err != nil {
		log.Println("couldn't unzip skin:", err)
		return defaultSkin
	}

	return skinName
}

// installSkin updates the config file so that it contains the provided skin.
func installSkin(skin string) {
	b, err := ioutil.ReadFile(osuCfg)
	if err != nil {
		log.Println("couldn't read config file:", err)
		return
	}

	skinLine := "Skin = " + skin
	lines := strings.Split(string(b), "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "Skin =") {
			if line == skinLine {
				return
			}
			lines[i] = "Skin = " + skin
			break
		}
	}
	newCfg := []byte(strings.Join(lines, "\n"))
	if err := ioutil.WriteFile(osuCfg, newCfg, os.ModePerm); err != nil {
		log.Println("couldn't update config file:", err)
		return
	}
}

// downloadMapset ensures that a mapset is downloaded.
func downloadMapset(setID int) error {
	files, err := ioutil.ReadDir(mapsDir)
	if err != nil {
		return err
	}

	for _, f := range files {
		if !f.IsDir() {
			continue
		}

		if strings.HasPrefix(f.Name(), strconv.Itoa(setID)+" ") {
			log.Println("found existing mapset", f.Name())
			return nil
		}
	}

	// TODO: Download the mapset.
	return errors.New("mapset not found")
}
