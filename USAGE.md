# Usage

This document is for users of the Discord bot and the client app.

## Discord Bot

The Discord bot lets you view and control the state of the application.

### Commands

All commands are prefixed by a mention of the bot.

#### `list jobs`

Replies with a summary of all active (pending or in progress) jobs.

#### `list workers`

Replies with a summary of all workers (including offline).

#### `describe job <id>`

Replies with a detailed summary of one job.

#### `describe worker <id>`

Replies with a detailed summary of one worker.

#### `delete job <id>`

Deletes a job.

#### `process queue`

Processes the job queue, which will assign pending jobs to workers.
The queue is processed automatically on an interval and whenever a new job is created, so you shouldn't really need to use it.
But it's still here just in case.

#### `shutdown`

Asks for confirmation to shut down.
You shouldn't ever need to use this, but if the bot is going haywire, spamming messages, etc., it's here for you.

### Replay Attachment

To create a recording job from a replay file, attach a `.osr` file and mention the bot.

### Reddit Posts

The bot will notify the channel about new score posts on Reddit.
To create a job for the posted play, react with a thumbs up to the message.
This method is slightly less reliable, so if you're informed of a failure, you can just go to the map's leaderboard and download the replay to use the previous method.

## Client App

### Setup

You should have received a folder called `OAAS` and an API key.

Move the `OAAS` folder to your osu! install folder.
Then, enter the `OAAS` folder and edit the `config.yml` file:

```yaml
api_key: The API key you were given.
obs_out_dir: The folder to which OBS outputs recordings (for example: C:\Users\YourUsername\Videos).
```

Next, you'll have to do a bit of OBS configuration:

* Set the output format to MP4
* Set a keyboard shortcut to start recording: `CTRL + ALT + SHIFT + O`
* Set a keyboard shortcut to stop recording: `CTRL + ALT + SHIFT + P`
* Set the scene to the one you want to record with

Next, configure your prompt to avoid freezing:

* Run Command Prompt
* Click on the top left of the window, then "Defaults"
* In the options menu, untick the "Quick Edit Mode" option

This will be enabled by default on Windows 10, but if you can find it on other versions do make sure it's unticked.

Finally, run the `get-coords.exe` application by double clicking, and follow the prompts.

### Running

Make sure OBS is running.
Then, double click the app to start it.
