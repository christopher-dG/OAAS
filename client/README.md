# OAAS Client

Install the [Go compiler](https://golang.org), and dependencies for [robotgo](https://github.com/go-vgo/robotgo#requirements).

Compile the client:

```sh
$ go build
```

Create a `config.yml`:

```yaml
api_url: http://localhost:4000
api_key: key
osu_root: /path/to/osu/installation
```

Run the client:

```sh
$  ./oaas -c config.yml
```

If running Windows, you may need to move the DLL files in `dll/` into the working directory.
