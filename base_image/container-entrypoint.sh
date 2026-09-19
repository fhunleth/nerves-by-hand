#!/bin/sh
set -eu

chmod 0777 /work/output
exec setpriv --reuid=1000 --regid=1000 --init-groups "$@"
