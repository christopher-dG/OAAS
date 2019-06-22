# OAAS Server

Install [Elixir](https://elixir-lang.org) and a [C compiler](https://gcc.gnu.org).
You'll need Elixir 1.8 and OTP 21.2 ([`asdf`](https://asdf-vm.com) can help with this).

Generate a cookie, and save it somewhere.
You'll, need this environment variable set whenever you want to interact with the running application.

```sh
$ export COOKIE=$(head -c100 /dev/urandom | sha256sum | cut -d' ' -f1)
```

Download dependencies, and create a release:

```sh
$ export MIX_ENV=prod
$ mix do local.hex --force, local.rebar --force, deps.get, release
```

You should now have a directory `_build/prod/rel/oaas`.
Copy this to `$DEST` where `$DEST` is wherever you want the application to reside.
Add the management script to your path:

```sh
$ export DEST="$HOME/oaas"
$ cp -r _build/prod/rel/oaas "$DEST"
$ export PATH="$PATH:$DEST/bin"
```

Next, copy the [example configuration file](config/example.toml) to `$DEST` and update it appropriately:

```sh
$ cp config/example.toml "$DEST/config.toml"
$ nano "$DEST/config.toml"  # Make your changes.
```

Manage the application with the `oaas` script.
Here are some common arguments:

- `start`: Run in the background.
- `remote_console`: Connect a console to running background session.
- `stop`: Stop the running application.
- `console`: Run a console in the foreground.

To manage API keys (these require the `sqlite3` executable:

- `list_keys`: Print out existing API keys.
- `add_key <key>`: Add an API key.
- `delete_key <key>`: Delete an API key.

You might also want to use systemd, in which case see [here](https://hexdocs.pm/distillery/guides/systemd.html).
