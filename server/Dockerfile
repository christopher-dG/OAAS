FROM elixir:1.8-alpine

WORKDIR /root/oaas

ENV MIX_ENV="prod" \
    BUILD_PKGS="gcc git musl-dev" \
    PKGS=""

COPY . .

RUN . ./.env && \
    apk update && \
    apk add $BUILD_PKGS $PKGS && \
    mix do local.hex --force, local.rebar --force, deps.get, compile && \
    apk del $BUILD_PKGS

ENTRYPOINT ["/root/oaas/entrypoint.sh"]

CMD mix run --no-deps-check --no-halt
