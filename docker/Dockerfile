FROM debian:buster-slim
MAINTAINER Kyle M Hall <kyle@bywatersolutions.com>

ENV PERL5LIB /kohalib
ENV KOHA_CONF /koha-conf.xml
ENV NCIP_PORT 3000
ENV MAX_WORKERS 2
ENV MAX_REQS_PER_CHILD 500

RUN apt-get -y update \
    && apt-get -y install curl wget gnupg2 coreutils cpanminus make \
    && wget -q -O- https://debian.koha-community.org/koha/gpg.asc | apt-key add - \
    && echo 'deb http://debian.koha-community.org/koha stable main' | tee /etc/apt/sources.list.d/koha.list \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/*

RUN apt-get update -y \
    && apt-get -y install \
       koha-perldeps \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/*

WORKDIR /app
COPY . .
COPY ./docker/files/config.yml.template ./config.yml
COPY docker/files/log4perl.conf.template t/config_sample/log4perl.conf

RUN cpanm -n Module::Install
RUN cpanm -n --installdeps .

CMD plackup -s Gazelle --port $NCIP_PORT --max-workers $MAX_WORKERS --max-reqs-per-child $MAX_REQS_PER_CHILD -E production -a bin/ncip_dancing.pl
