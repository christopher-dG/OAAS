# OAAS Server

Install [Elixir](https://elixir-lang.org) and a [C compiler](https://gcc.gnu.org).
You'll need Elixir 1.9 and OTP 21.2 ([`asdf`](https://asdf-vm.com) can help with this).

Download dependencies, and create a release:

```sh
$ export MIX_ENV=prod
$ mix do local.hex --force, local.rebar --force, deps.get, release prod
```

You should now have a directory `_build/prod/rel/oaas`.
Copy this to `$DEST` where `$DEST` is wherever you want the application to reside.
Rename the management script and add it to your path:

```sh
$ export DEST="$HOME/oaas"
$ cp -r _build/prod/rel/prod "$DEST"
$ mv "$DEST/bin/prod" "$DEST/bin/oaas"
$ export PATH="$PATH:$DEST/bin"
```

Next, copy the [example configuration file](config/example.toml) to `$DEST` and update it appropriately:

```sh
$ cp config/example.toml "$DEST/config.toml"
$ nano "$DEST/config.toml"  # Make your changes.
```

Manage the application with the `oaas` script.
Here are some common arguments:

- `start`: Run in the foreground.
- `daemon`: Run in the background.
- `remote`: Connect a console to a running background session.
- `stop`: Stop the running application.

To manage API keys, use `eval` with the `OAAS.CLI` module:

```sh
$ oaas eval 'OAAS.CLI.add_keys(["foo", "bar"])'
```

The available tasks are:

- `list_keys()`: Print out existing API keys.
- `add_keys(key | [keys])`: Add one API key, or a list of them.
- `delete_keys(key | [keys])`: Delete one API key, or a list of them.

If you already have the application running, you can switch out `eval` for `rpc` for a quicker boot.
