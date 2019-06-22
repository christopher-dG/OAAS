# OAAS Server

## Without Docker

Install [Elixir](https://elixir-lang.org), [Git](https://git-scm.com), and a [C compiler](https://gcc.gnu.org).
You need Elixir 1.8 and OTP 21.2.

Download dependencies:

```sh
$ mix do local.hex --force, local.rebar --force, deps.get
```

Create a `.env` file:

```sh
export PORT="4000"
export OSU_API_KEY="key"
export OSUSEARCH_API_KEY="key"
export DISCORD_TOKEN="token"
export DISCORD_CHANNEL="123"
export DISCORD_USER="321"
export DISCORD_ADMIN_ID="123"
export REDDIT_USER_AGENT="agent"
export REDDIT_USERNAME="user"
export REDDIT_PASSWORD="password"
export REDDIT_CLIENT_ID="id"
export REDDIT_CLIENT_SECRET="secret"
export REDDIT_SUBREDDIT="sub"
```

Start the application:

```sh
$ MIX_ENV=prod mix start --no-halt
```

List, add or delete API keys like so:

```sh
$ MIX_ENV=prod mix oaas.key.list
$ MIX_ENV=prod mix oaas.key.add [keys...]
$ MIX_ENV=prod mix oaas.key.delete [keys...]
```

Back up the database with another Mix task:

```sh
$ MIX_ENV=prod mix oaas.db.dump > db_backup.sqlite3
```

## With Docker

Or, you can use Docker.

With the same `.env` file present, build the image, create a container, and start it:

```sh
$ docker build -t oaas .
$ docker create --name oaas -p 4000:4000 oaas
$ docker start oaas
```

Run Mix tasks with `docker exec`:

```sh
$ docker exec oaas mix oaas.key.list
$ docker exec oaas mix oaas.key.add [keys...]
$ docker exec oaas mix oaas.key.delete [keys...]
$ docker exec oaas mix oaas.db.dump > db_backup.sqlite3
```

Note: Don't share the built image, as it contains your `.env` file.
