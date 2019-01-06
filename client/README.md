# OAAS Client

The client is Windows-only; these instructions assume that you're cross-compiling from Linux.

Install the [Go compiler](https://golang.org) and [AutoHotkey](https://autohotkey.com) (with [Wine](https://www.winehq.org)).

Compile the client:

```sh
$ GOOS=windows go build -o OAAS/oaas.exe
```

Compile any scripts in `ahk/` excluding `base.ahk`:

```sh
$ Ahk2Exe.exe /in ahk/record-replay.ahk /out OAAS/record-replay.exe
```

Update `OAAS/config.yml` to match your server configuration:

```yaml
api_url: The server URL.
```

Copy `OAAS/` to the osu! install directories of your client computers.
On each of them, update `config.yml` again:

```yaml
api_key: An API key created that has been added to the server.
obs_out_dir: The directory that OBS is configured to output recordings.
```

Run the client by simply executing it.
