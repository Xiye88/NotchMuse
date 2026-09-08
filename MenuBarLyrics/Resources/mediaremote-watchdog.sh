#!/bin/sh
set -eu

parent_pid=$PPID
/usr/bin/perl "$@" &
child_pid=$!

cleanup() {
  kill "$child_pid" 2>/dev/null || true
  wait "$child_pid" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

while kill -0 "$child_pid" 2>/dev/null; do
  kill -0 "$parent_pid" 2>/dev/null || exit 0
  sleep 1
done

wait "$child_pid"
