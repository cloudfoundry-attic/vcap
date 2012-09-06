#!/bin/bash
for n in `seq 1 100`; do
  if [ -f /tmp/vcap_chown.out ]; then
    break
  fi
  sleep 0.1
done

touch /store/log/mongodb.log
mkdir -p /store/instance/data

# mongod_startup.sh 1.8
# mongod_startup.sh 1.8 --journal
# mongod_startup.sh 2.0
# mongod_startup.sh 2.0 --nojournal
if [ $# -gt 0 ]; then
  if [ $1 = "1.8" ]; then
    params="--journal"
    arguments=""

    shift
    while [ $# -ne 0 ]; do
      for i in $params; do
        if [ $1 = $i ]; then
          arguments="$arguments $1"
        fi
      done
      shift
    done

    exec /usr/share/mongodb/mongodb-1.8/mongod $arguments --config /etc/mongodb.conf
  elif [ $1 = "2.0" ]; then
    params="--nojournal"
    arguments=""

    shift
    while [ $# -ne 0 ]; do
      for i in $params; do
        if [ $1 = $i ]; then
          arguments="$arguments $1"
        fi
      done
      shift
    done

    exec /usr/share/mongodb/mongodb-2.0/mongod $arguments --config /etc/mongodb.conf
  fi
fi
