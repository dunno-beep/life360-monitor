#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-}"; DEV="${2:-}"; VIEW="${3:-}"; CTL="${4:-}"
if [ -z "$HOST" ] || [ -z "$DEV" ] || [ -z "$VIEW" ]; then
  echo "usage: bash configure.sh <relay-host> <device-secret> <viewer-secret> [control-secret]"
  exit 1
fi
CTL="${CTL:-$VIEW}"
export HOST DEV VIEW CTL
python3 - <<'PY'
import os, re, pathlib
H, D, V, C = (os.environ[k] for k in ("HOST", "DEV", "VIEW", "CTL"))
sw = pathlib.Path("iphone/Config.swift"); s = sw.read_text()
s = re.sub(r'static let token\s*=\s*"[^"]*"',   f'static let token   = "{D}"', s)
s = re.sub(r'static let viewer\s*=\s*"[^"]*"',  f'static let viewer  = "{V}"', s)
s = re.sub(r'static let control\s*=\s*"[^"]*"', f'static let control = "{C}"', s)
s = re.sub(r'static let relayHost = "[^"]*"',   f'static let relayHost = "{H}"', s)
sw.write_text(s)
gd = pathlib.Path("android/app/build.gradle.kts"); g = gd.read_text()
g = re.sub(r'buildConfigField\("String", "RELAY", "[^"]*"\)',
           f'buildConfigField("String", "RELAY", "\\\\"{H}:8080\\\\"")', g)
g = re.sub(r'buildConfigField\("String", "TOKEN", "[^"]*"\)',
           f'buildConfigField("String", "TOKEN", "\\\\"{D}\\\\"")', g)
m = re.search(r'versionCode = (\d+)', g)
g = g.replace(m.group(0), f'versionCode = {int(m.group(1)) + 1}')
gd.write_text(g)
print("versionCode ->", re.search(r'versionCode = (\d+)', g).group(1))
PY
printf '%s\n' "$DEV" > .device
printf '%s\n' "$VIEW" > .viewer
printf '%s\n' "$CTL" > .control
echo "$CTL" > .control
echo "Configured for $HOST"
