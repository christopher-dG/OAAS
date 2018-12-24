# OAAS Server

Install [Elixir](https://elixir-lang.org), and a C compiler for [Sqlitex](https://github.com/elixir-sqlite/sqlitex).

Next, download dependencies:

```sh
$ mix deps.get
```

Then, set required environment variables (see `config/config.exs` for more details):

```sh
$ export OSU_API_KEY="key"
$ export DISCORD_TOKEN="token"
$ export DISCORD_CHANNEL="channel"
$ export DISCORD_USER="user"
```

Run the server:

```sh
$ mix run --no-halt
```
