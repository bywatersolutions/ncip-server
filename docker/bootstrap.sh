docker run -d --restart=always -p 3000:4000 \
              --mount type=bind,source=/usr/share/koha/lib/,target=/kohalib \
              --mount type=bind,source=/etc/koha/sites/$INSTANCE/koha-conf.xml,target=/koha-conf.xml \
              --mount type=bind,source=/etc/koha/sites/$INSTANCE/ncip-config.yml,target=/app/config.yml \
              --mount type=bind,source=/var/run/mysqld/mysqld.sock,target=/var/run/mysqld/mysqld.sock \
              --name koha-ncip-$INSTANCE bywater/koha-ncip-server:latest
