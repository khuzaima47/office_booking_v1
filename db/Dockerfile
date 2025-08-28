FROM ubuntu:jammy

ENV PG_MAJOR 15
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

ARG DEBIAN_FRONTEND=noninteractive

# explicitly set user/group IDs
RUN set -eux && \
	groupadd -r postgres --gid=1000 && \
    useradd -r -g postgres --uid=1000 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres && \
    mkdir -p /var/lib/postgresql && \
	chown -R postgres:postgres /var/lib/postgresql

# install postgres
RUN set -eux && \
	apt-get update && \
    apt-get install -y --no-install-recommends curl wget gnupg ca-certificates && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-common && \
	sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf && \
	apt-get install -y --no-install-recommends postgresql-15 postgresql-15-repack

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN set -eux && \
	if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
        # if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
		grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
		sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
		! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
	fi; \
	apt-get update && apt-get install -y --no-install-recommends locales && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
	dpkg-divert --add --rename --divert "/usr/share/postgresql/postgresql.conf.sample.dpkg" "/usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample"; \
	cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg /usr/share/postgresql/postgresql.conf.sample; \
	ln -sv ../postgresql.conf.sample "/usr/share/postgresql/$PG_MAJOR/"; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/share/postgresql/postgresql.conf.sample

ENV PGDATA /var/lib/postgresql/data
STOPSIGNAL SIGINT
EXPOSE 5432

################################################
# MY TOOLS
################################################

RUN apt-get -y update \
    && apt-get -y install sudo procps net-tools iputils-ping curl jq xonsh fish

## install Python (/usr/bin/python3.11)
RUN apt update -y \
    && apt -y install software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt update -y \
    && apt install -y python3.11
ENV PYTHONUNBUFFERED=1

COPY ./scripts /scripts
RUN chmod +x /scripts/*.xsh

ENTRYPOINT [ "python3.11", "/cscripts/seq_exec.py" ]
CMD [ "/scripts/init.xsh" ]