FROM elixir:1.7

ENV MIX_ENV prod

WORKDIR /root/oaas

COPY . .

RUN . ./.env && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install python-pip && \
    pip install praw && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix compile

ENTRYPOINT ["/root/oaas/entrypoint.sh"]

CMD mix run --no-halt
