#!/bin/sh


echo "listen_addresses = '*'" >> /etc/postgresql/9.6/main/postgresql.conf

/usr/sbin/service postgresql start
