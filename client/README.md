# OAAS Client

These instructions assume that you're cross-compiling for Windows from Linux.

Install the [Go compiler](https://golang.org) and [AutoHotkey](https://autohotkey.com) (with [Wine](https://www.winehq.org)).

Compile the client:

```sh
$ GOOS=windows go build -o OAAS/oaas.exe
```

Compile any scripts in `ahk/` excluding `base.ahk`:

```sh
$ Ahk2Exe.exe /in ahk/get-coords.ahk /out OAAS/get-coords.exe
$ Ahk2Exe.exe /in ahk/record-replay.ahk /out OAAS/record-replay.exe
```

If your workers will be uploading to YouTube, follow the instructions [here](https://github.com/porjo/youtubeuploader#youtube-api) to create YouTube credentials, then update the `client_id` and `client_secret` keys in `OAAS/client_secrets.json` to match.

Download a compiled copy of [YouTube Uploader](https://github.com/porjo/youtubeuploader) and generate OAuth2 credentials:

```sh
$ curl -L https://github.com/porjo/youtubeuploader/releases/download/19.02/youtubeuploader_linux_amd64.tar.gz | tar zx
$ echo x | ./youtubeuploader_linux_amd64 -filename - -secrets OAAS/client_secrets.json
$ mv request.token OAAS
$ rm youtubeuploader_linux_amd64
```
Also download a copy for the workers:

```sh
$ curl -L https://github.com/porjo/youtubeuploader/releases/download/19.02/youtubeuploader_windows_amd64.zip -o uploader.zip
$ unzip uploader.zip
$ mv youtubeuploader_windows_amd64.exe OAAS/youtube-uploader.exe
$ rm uploader.zip
```

Update `OAAS/config.yml` to match your server configuration:

```yaml
api_url: The server URL.
uploader: The upload destination/strategy to use (currently only "youtube" is supported).
```
