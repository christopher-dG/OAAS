# OAAS Server

Setup is most simple with Docker.

Create a `.env` file:

```sh
export PORT=4000
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

Build the image:

```sh
$ docker build -t oaas .
```

Create and start it:

```sh
$ docker create --name oaas -p 4000:4000 oaas
$ docker start oaas
```

Add or delete API keys like so:

```sh
$ docker exec oaas mix key.add <key>
$ docker exec oaas mix key.delete <key>
```

Note: Don't share the built image, as it contains your `.env` file.
