#!/bin/bash -eu

# Copyright 2013 tsuru authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

echo Installing kernel extra package
apt-get update
apt-get install linux-image-extra-`uname -r` -qqy

echo Adding Docker repository
curl https://get.docker.io/gpg | apt-key add -
echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list

echo Adding Tsuru repository
apt-add-repository ppa:tsuru/ppa -y

echo Adding MongoDB repository
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen > /etc/apt/sources.list.d/mongodb.list

echo Installing MongoDB
apt-get update
apt-get install mongodb-10gen -qqy

echo Installing remaining packages
apt-get update
apt-get install lxc-docker tsuru-server beanstalkd redis-server node-hipache gandalf-server -qqy

echo Configuring and starting Docker
sed -i.old -e 's;/usr/bin/docker -d;/usr/bin/docker -H tcp://127.0.0.1:4243 -d;' /etc/init/docker.conf
rm /etc/init/docker.conf.old
restart docker

echo Installing bare-template for Gandalf repositories
hook_dir=/home/git/bare-template/hooks
mkdir -p $hook_dir
curl https://raw.github.com/globocom/tsuru/master/misc/git-hooks/post-receive -o ${hook_dir}/post-receive
chmod +x ${hook_dir}/post-receive
chown -R git:git /home/git/bare-template

echo Configuring and starting Gandalf
cat > /etc/gandalf.conf <<EOF
bin-path: /usr/bin/gandalf-ssh
git:
  bare:
    location: /var/lib/gandalf/repositories
    template: /home/git/bare-template
host: localhost
bind: localhost:8000
uid: git
EOF
restart gandalf-server

echo Starting git-daemon
restart git-daemon

echo Configuring and starting beanstalkd
cat > /etc/default/beanstalkd <<EOF
BEANSTALKD_LISTEN_ADDR=127.0.0.1
BEANSTALKD_LISTEN_PORT=11300
DAEMON_OPTS="-l $BEANSTALKD_LISTEN_ADDR -p $BEANSTALKD_LISTEN_PORT -b /var/lib/beanstalkd"
START=yes
EOF
service beanstalkd start

echo Configuring and starting Tsuru
curl -o /etc/tsuru/tsuru.conf http://script.cloud.tsuru.io/conf/tsuru-single.conf
sed -i.old -e 's/=no/=yes/' /etc/default/tsuru-server
rm /etc/default/tsuru-server.old
start tsuru-server-api
start tsuru-server-collector
