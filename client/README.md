# OAAS Client

### Host Preparation

Here, "host" just means the computer preparing the client bundle.
These instructions assume that you're cross-compiling for Windows from Linux.

Install the [Go compiler](https://golang.org) and [AutoHotkey](https://autohotkey.com) (with [Wine](https://www.winehq.org)).

Compile the client:

```sh
$ GOOS=windows go build -o OAAS/oaas.exe
```

Compile any scripts in `ahk/` excluding `base.ahk`:

```sh
$ Ahk2Exe.exe /in ahk/record-replay.ahk /out OAAS/record-replay.exe
```

Download a compiled copy of [YouTube Uploader](https://github.com/porjo/youtubeuploader):

```sh
curl -L https://github.com/porjo/youtubeuploader/releases/download/18.15/youtubeuploader_windows_amd64.zip -o uploader.zip
unzip uploader.zip
mv youtubeuploader_windows_amd64.exe OAAS/youtube-uploader.exe
rm uploader.zip
```

Update `OAAS/config.yml` to match your server configuration:

```yaml
api_url: The server URL.
uploader: The upload destination/strategy to use (currently only "youtube" is supported).
```

### Guest Preparation

Here, "guest" refers to the computers running the client.

Copy the `OAAS/` directory from earlier to the osu! install directory.
Update `config.yml` again:

```yaml
api_key: An API key that has been added to the server.
obs_out_dir: The directory to which OBS outputs recordings.
```

OBS must be configured manually, no settings such as sources or scenes are changed automatically by the client.
The recording output format must be set to MP4.
Keyboard shortcuts must also be set up to start and stop recording.
Start is `CTRL + ALT + SHIFT + O`, and stop is the same but with `P`.

If `uploader` was set to "youtube", then follow the instructions [here](https://github.com/porjo/youtubeuploader#youtube-api) to create YouTube credentials.
Next, update `client_secrets.json` with your client ID and secret.
Then, execute `youtube-auth.ps1` and follow the prompts.

Finally, run the client by simply executing it.
