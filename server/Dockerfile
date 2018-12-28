FROM elixir:1.7

WORKDIR /root/oaas

RUN curl -sL https://deb.nodesource.com/setup_11.x | bash && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install nodejs python-pip && \
    mix local.hex --force && \
    mix local.rebar --force && \
    pip install praw && \
    git clone https://github.com/omkelderman/osu-replay-downloader /root/osr-dl && \
    cd /root/osr-dl && \
    tr '\r' ' ' < fetch.js | cat > fetch2.js && \
    mv fetch2.js fetch.js && \
    chmod +x fetch.js && \
    npm install

COPY . .

ENV MIX_ENV=prod OSR_DOWNLOADER=/root/osr-dl/fetch.js

RUN . ./.env && \
    mix deps.get && \
    mix compile

ENTRYPOINT ["/root/oaas/entrypoint.sh"]

CMD mix run --no-halt
