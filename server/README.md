# OAAS Server

Install [Elixir](https://elixir-lang.org), a C compiler, [Python](https://python.org), and [PRAW](https://github.com/praw-dev/praw).

Next, download dependencies:

```sh
$ mix deps.get
```

Then, set required environment variables (see `config/config.exs` for more details):

```sh
$ export OSU_API_KEY="key"
$ export DISCORD_TOKEN="token"
$ export DISCORD_CHANNEL="123"
$ export DISCORD_USER="321"
$ export REDDIT_USER_AGENT="agent"
$ export REDDIT_USERNAME="user"
$ export REDDIT_PASSWORD="password"
$ export REDDIT_CLIENT_ID="id"
$ export REDDIT_CLIENT_SECRET="secret"
$ export REDDIT_SUBREDDIT="sub"
```

Run the server:

```sh
$ mix run --no-halt
```
