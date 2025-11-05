#!/usr/bin/env bash
set -euo pipefail

# Simple health check: ensure xo-server http port responds
HOST=${HOST:-localhost}
PORT=${PORT:-8080}

if curl -fsS http://$HOST:$PORT/version >/dev/null; then
  exit 0
fi

# fallback: root path
curl -fsS http://$HOST:$PORT/ >/dev/null
