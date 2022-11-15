ARG BASE_REGISTRY=docker.io
ARG BASE_IMAGE=zarguell/ubi8
ARG BASE_TAG=latest

FROM postgres:14.6 as upstream

FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG}

ENV PGDATA=/var/lib/postgresql/data

USER 0

RUN groupadd -g 1001 postgres && \
    useradd -r -u 1001 -m --home-dir=/var/lib/postgresql --shell=/bin/bash -g postgres postgres && \
    mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql

COPY --from=upstream --chown=root:root --chmod=755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

## not needed, not in ubi
# RUN dnf -qy module disable postgresql

## TODO: test nogpgcheck, pg15 was unsigned
RUN rpm --import https://ftp.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-AARCH64-RHEL8 && \
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-aarch64/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf update -y && \
    dnf install -y --nogpgcheck glibc-langpack-en postgresql14-server postgresql14 postgresql14-libs postgresql14-contrib && \
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    rm -rf /usr/share/doc/perl-IO-Socket-SSL/certs/* && \
    rm -rf /usr/share/doc/perl-IO-Socket-SSL/example && \
    rm -rf /usr/share/doc/perl-Net-SSLeay/examples && \
    chmod +x /usr/local/bin/docker-entrypoint.sh &&\
    chmod o-w /usr/local/bin/docker-entrypoint.sh

RUN mkdir /docker-entrypoint-initdb.d && \
    chown postgres:postgres /docker-entrypoint-initdb.d && \
    chmod 755 /docker-entrypoint-initdb.d && \
    mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql/data && \
    chmod 775 /var/lib/postgresql/data && \
    sed -ri s/"#?(listen_addresses)\s*=\s*\S+.*"/"listen_addresses = '*'"/ /usr/pgsql-14/share/postgresql.conf.sample && \
    sed -ri s/"#?(log_destination)\s*=\s*\S+.*"/"log_destination = 'stderr'"/ /usr/pgsql-14/share/postgresql.conf.sample && \
    sed -ri s/"#?(logging_collector)\s*=\s*\S+.*"/"logging_collector = off"/ /usr/pgsql-14/share/postgresql.conf.sample && \
    grep -F "listen_addresses = '*'" /usr/pgsql-14/share/postgresql.conf.sample

# commented out due to CrashLoopBackoff in a cluster without Docker (issue: https://repo1.dso.mil/dsop/opensource/postgres/postgresql12/-/issues/5)
# VOLUME /var/lib/postgresql/data

USER postgres

ENV PGDATA=/var/lib/postgresql/data
ENV PATH $PATH:/usr/pgsql-14/bin
ENV LANG en_US.utf8

HEALTHCHECK --interval=5s --timeout=3s CMD /usr/pgsql-14/bin/pg_isready -U postgres

ENTRYPOINT ["docker-entrypoint.sh"]

STOPSIGNAL SIGINT

EXPOSE 5432

CMD ["postgres"]
