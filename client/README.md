# OAAS Client

Install the [Go compiler](https://golang.org), and dependencies for [robotgo](https://github.com/go-vgo/robotgo#requirements).

Compile the client:

```sh
$ go build
```

Put it in `OAAS`:

```sh
$ cp oaas OAAS
```

Edit `config.yml` to match your server and system configuration:

```yaml
api_url: http://localhost:4000
api_ley: key
simple_skin_loading: true
obs_port: 4444
obs_password: password
```

Move the folder to your osu! install directory:

```sh
$ cp -r OAAS ~/osu!
```

Run the client:

```sh
$  ./oaas
```
