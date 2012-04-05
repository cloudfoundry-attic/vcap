#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

if [ ! -f started ]; then
  echo "Container is not running..."
  exit 1
fi

# Disallow new logins for the vcap user and kill running processes
ssh -F ssh/ssh_config root@container <<EOS
chsh -s /bin/false vcap

# Send SIGTERM
pkill -TERM -U vcap || true

# Wait for processes to exit
for i in \$(seq 10); do
  [ \$(pgrep -U vcap | wc -l) -eq 0 ] && break
  sleep 1
done

# Send SIGKILL
pkill -KILL -U vcap || true
EOS
