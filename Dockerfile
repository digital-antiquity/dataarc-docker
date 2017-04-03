FROM ubuntu:xenial

MAINTAINER adam.brin@asu.edu

RUN groupadd -r postgres && useradd -r -g postgres postgres
# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mongodb && useradd -r -g mongodb mongodb

# setup gosu for use from entrypoint script
ENV GOSU_VERSION 1.9

ENV PG_VERSION 9.6

######### POSTGRES #########

RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates software-properties-common   wget \
    && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get purge -y --auto-remove ca-certificates \
    && rm -rf /var/lib/apt/lists/*


# set locale
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8

RUN touch /etc/apt/sources.list.d/pgdg.list \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" >> /etc/apt/sources.list.d/pgdg.list \
    && wget --no-check-certificate  --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update &&  apt-get install \
    && apt-get install -y --no-install-recommends postgresql-9.6 postgresql-client-9.6 postgis postgresql-9.6-postgis-2.3 postgresql-contrib-9.6 postgresql-9.6-postgis-2.3-scripts



EXPOSE 5432

VOLUME ["/var/lib/postgresql"]

# CMD /scripts/db_start.sh

######### MONGO #########

RUN touch /etc/apt/sources.list.d/pgdg.list \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" >> /etc/apt/sources.list.d/pgdg.list \
    && wget --no-check-certificate  --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update &&  apt-get install \
    && apt-get install -y --no-install-recommends mongodb mongodb-clients mongodb-server \
	&& rm -rf /var/lib/apt/lists/* 
    
VOLUME ["/var/lib/mongodb"]

# COPY docker-entrypoint.sh /entrypoint.sh
# ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 27017
# CMD ["mongod"]

######### JAVA #########


# Install Java.
RUN apt-get update && apt-get install -y  --no-install-recommends software-properties-common \
  && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer

RUN mkdir -p /data/db /data/configdb \
    && chown -R mongodb:mongodb /data/db /data/configdb
VOLUME /data/db /data/configdb


# COPY docker-entrypoint.sh /entrypoint.sh
# RUN chmod 755 /entrypoint.sh
# ENTRYPOINT ["/entrypoint.sh"]

# Define working directory.
WORKDIR /data


VOLUME /dataarc

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle


##### MAVEN

ARG MAVEN_VERSION=3.5.0-alpha-1
ARG USER_HOME_DIR="/root"
ARG SHA1=a677b8398313325d6c266279cb8d385bbc9d435d
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries



RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && wget -O /tmp/apache-maven.tar.gz "${BASE_URL}/apache-maven-$MAVEN_VERSION-bin.tar.gz" \
  && echo "${SHA1}  /tmp/apache-maven.tar.gz" | sha1sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

VOLUME "$USER_HOME_DIR/.m2"

COPY pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf
RUN chown postgres:postgres /etc/postgresql/9.6/main/pg_hba.conf
USER postgres
COPY pg-start.sh /pg-start.sh
RUN sh /pg-start.sh
USER root
COPY mg-start.sh /mg-start.sh
RUN sh /mg-start.sh
# RUN chmod 755 /start.sh
COPY start.sh /start.sh

ENTRYPOINT ["/bin/sh", "-c", "/start.sh"]
EXPOSE 8280

# CMD mongod