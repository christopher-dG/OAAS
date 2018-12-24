#!/bin/sh

cd /root/oaas
. ./.env
exec "$@"
