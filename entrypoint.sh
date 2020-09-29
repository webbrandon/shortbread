#!/bin/bash
set -e
rm tmp/pids/server.pid
exec "$@"
