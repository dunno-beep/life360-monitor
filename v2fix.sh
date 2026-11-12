#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
K=android/app/src/main/java/com/you/life360monitor/Crypto.kt
S=iphone/Crypto.swift
p() { python3 - "$1" "$2" "$3" <<'PY'
import sys, pathlib
f, old, new = sys.argv[1:4]
q = pathlib.Path(f); s = q.read_text()
if new in s: print("  already", f); raise SystemExit
if old not in s: print("  ANCHOR GONE", f, "->", old[:50]); raise SystemExit(1)
q.write_text(s.replace(old, new, 1)); print("  patched", f)
PY
}
p "$K" 'return mac.doFinal("l360.v2".toByteArray()).copyOf(32)' \
       'return mac.doFinal("l360.v2".toByteArray() + byteArrayOf(1)).copyOf(32)'
p "$K" 'upCount += 1' 'upCount = maxOf(upCount + 1, System.currentTimeMillis())'
p "$S" 'let n = (last[dir] ?? 0) + 1' \
       'let n = max((last[dir] ?? 0) + 1, UInt64(Date().timeIntervalSince1970 * 1000))'
