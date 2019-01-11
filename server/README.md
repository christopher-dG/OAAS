# OAAS Server

## Without Docker

Install [Elixir](https://elixir-lang.org), [Git](https://git-scm.com), and a [C compiler](https://gcc.gnu.org).

Download dependencies:

```sh
$ mix do local.hex --force, local.rebar --force, deps.get
```

Create a `.env` file:

```sh
export PORT="4000"
export OSU_API_KEY="key"
export DISCORD_TOKEN="token"
export DISCORD_CHANNEL="123"
export DISCORD_USER="321"
export REDDIT_USER_AGENT="agent"
export REDDIT_USERNAME="user"
export REDDIT_PASSWORD="password"
export REDDIT_CLIENT_ID="id"
export REDDIT_CLIENT_SECRET="secret"
export REDDIT_SUBREDDIT="sub"
```

Start the application:

```sh
mix start --no-halt
```

List, add or delete API keys like so:

```sh
$ oaas mix key.list
$ mix key.add [keys...]
$ mix key.delete [keys...]
```

## With Docker

Or, you can use Docker.

With the same `.env` file present, build the image, create a container, and start it:

```sh
$ docker build -t oaas .
$ docker create --name oaas -p 4000:4000 oaas
$ docker start oaas
```

Manage keys with `docker exec`:

```sh
$ docker exec oaas mix key.list
$ docker exec oaas mix key.add [keys...]
$ docker exec oaas mix key.delete [keys...]
```

Note: Don't share the built image, as it contains your `.env` file.
