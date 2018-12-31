FROM elixir:1.7-alpine

WORKDIR /root/oaas

ENV MIX_ENV="prod" \
    OSR_DOWNLOADER="/root/osr-dl/fetch.js" \
    BUILD_PKGS="gcc git musl-dev nodejs-npm py-pip" \
    PKGS="nodejs python"

COPY . .

RUN sed -i s/OSR_DOWNLOADER/_OSR_DOWNLOADER/g .env && \
    . ./.env && \
    apk update && \
    apk add $BUILD_PKGS $PKGS && \
    pip --disable-pip-version-check install praw && \
    mix do local.hex --force, local.rebar --force, deps.get, compile && \
    git clone https://github.com/omkelderman/osu-replay-downloader /root/osr-dl && \
    (cd /root/osr-dl && npm install) && \
    apk del $BUILD_PKGS

ENTRYPOINT ["/root/oaas/entrypoint.sh"]

CMD mix run --no-deps-check --no-halt
