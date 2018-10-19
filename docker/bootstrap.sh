#!/bin/bash

if [[ -z "$INSTANCE" ]]; then
    echo "You must set the environment variable INSTANCE to a Koha instance before running this script" 1>&2
    exit 1
fi

if [ ! -f /etc/koha/sites/$INSTANCE/ncip-config.yml ]; then
    echo "NCIP config not found, downloading default config file as /etc/koha/sites/$INSTANCE/ncip-config.yml";
    curl https://github.com/bywatersolutions/ncip-server/blob/master/docker/files/config.yml.template -o /etc/koha/sites/$INSTANCE/ncip-config.yml
fi

docker run -d --restart=always \
              -p 127.0.0.1:4000:3000 \
              --mount type=bind,source=/usr/share/koha/lib/,target=/kohalib \
              --mount type=bind,source=/etc/koha/sites/$INSTANCE/koha-conf.xml,target=/koha-conf.xml \
              --mount type=bind,source=/etc/koha/sites/$INSTANCE/ncip-config.yml,target=/app/config.yml \
              --mount type=bind,source=/var/run/mysqld/mysqld.sock,target=/var/run/mysqld/mysqld.sock \
              --name koha-ncip-$INSTANCE bywater/koha-ncip-server:latest
