#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/server"
[ -d node_modules ] || { [ -f package.json ] || npm init -y >/dev/null 2>&1; npm i >/dev/null 2>&1; }
export DEVICE_TOKEN="$(cat ../.device 2>/dev/null || echo CHANGE_ME)"
export VIEWER_TOKEN="$(cat ../.viewer 2>/dev/null || echo CHANGE_ME_VIEWER)"
export CONTROL_TOKEN="$(cat ../.control 2>/dev/null || echo CHANGE_ME_CONTROL)"
export HOST="$(sed -n 's/.*relayHost = "\(.*\)".*/\1/p' ../iphone/Config.swift)"
echo "relay on ${HOST:-0.0.0.0}:8080"
command -v termux-wake-lock >/dev/null && termux-wake-lock || true
exec node server.js
