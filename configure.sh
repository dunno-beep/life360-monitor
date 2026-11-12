#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-}"
[ -n "$HOST" ] || { echo "usage: bash configure.sh <relay-host> [token] [viewer] [control]"; exit 1; }
gen() { openssl rand -hex 24 2>/dev/null || date +%s%N | sha256sum | cut -c1-48; }
TOKEN="${2:-$(gen)}"; VIEW="${3:-$(gen)}"; CTL="${4:-$(gen)}"
export HOST TOKEN VIEW CTL
python3 - <<'PY'
import os, re, pathlib
H, T, V, C = (os.environ[k] for k in ("HOST","TOKEN","VIEW","CTL"))
sw = pathlib.Path("iphone/Config.swift"); s = sw.read_text()
for name, val in (("token", T), ("viewer", V), ("control", C), ("relayHost", H)):
    pat = rf'(static let {name}\s*=\s*)"[^"]*"'
    if re.search(pat, s):
        s = re.sub(pat, lambda m: m.group(1) + '"' + val + '"', s)
    else:
        print("warn: Config.swift has no", name)
sw.write_text(s)
gd = pathlib.Path("android/app/build.gradle.kts"); g = gd.read_text()
g = re.sub(r'buildConfigField\("String", "RELAY", ".*?"\)',
           lambda m: f'buildConfigField("String", "RELAY", "\\"{H}:8080\\"")', g)
g = re.sub(r'buildConfigField\("String", "TOKEN", ".*?"\)',
           lambda m: f'buildConfigField("String", "TOKEN", "\\"{T}\\"")', g)
m = re.search(r'versionCode = (\d+)', g)
if m: g = g.replace(m.group(0), f'versionCode = {int(m.group(1)) + 1}')
gd.write_text(g)
print("versionCode ->", re.search(r'versionCode = (\d+)', g).group(1))
PY
printf '%s\n' "$TOKEN" > .token
printf '%s\n' "$VIEW" > .viewer
printf '%s\n' "$CTL" > .control
echo "Configured for $HOST"
