#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[ -d .git ] || { echo "run from repo root"; exit 1; }
command -v python3 >/dev/null || pkg install python -y
termux-wake-lock 2>/dev/null || true

patched=0
patch() { # file  old  new
  python3 - "$1" "$2" "$3" <<'PY'
import sys, pathlib
f, old, new = sys.argv[1:4]
p = pathlib.Path(f)
if not p.exists(): print("  MISSING FILE", f); sys.exit(3)
s = p.read_text()
if new in s: print("  already", f); sys.exit(0)
if old not in s: print("  ANCHOR GONE in", f, "->", old[:60]); sys.exit(4)
p.write_text(s.replace(old, new, 1)); print("  patched", f)
PY
  patched=$((patched+1))
}

echo "== configure.sh"
cat > configure.sh <<'CFG'
#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-}"; TOKEN="${2:-}"
[ -n "$HOST" ] || { echo "usage: bash configure.sh <tailscale-ip> [secret]"; exit 1; }
[ -n "$TOKEN" ] || TOKEN="$(openssl rand -hex 24 2>/dev/null || date +%s%N | sha256sum | cut -c1-48)"
cat > iphone/Config.swift <<EOF
import Foundation

enum Config {
    static let appGroup    = "group.f0f60c3925d8a7e3.1"
    static let token       = "$TOKEN"
    static let brokerHost  = "broker.emqx.io"
    static let brokerPort  = 8084
    static let brokerPath  = "/mqtt"
    static let upTopic     = "l360/\(token)/up"
    static let downTopic   = "l360/\(token)/down"
    static let binTopic    = "l360/\(token)/bin"
    static let relayHost   = "$HOST"
    static let relayPort   = 8080
}
EOF
cat > android/app/build.gradle.kts <<EOF
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.you.life360monitor"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.you.life360monitor"
        minSdk = 26
        targetSdk = 33
        versionCode = 4
        versionName = "1.0"
        buildConfigField("String", "RELAY", "\"$HOST:8080\"")
        buildConfigField("String", "TOKEN", "\"$TOKEN\"")
    }

    buildFeatures { buildConfig = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation("org.eclipse.paho:org.eclipse.paho.client.mqttv3:1.2.5")
}
EOF
echo "$TOKEN" > .token
echo "Configured. Token: $TOKEN"
CFG
chmod +x configure.sh

echo "== extension bundle id"
patch iphone/App.swift 'com.you.life360.screen' 'app.cassava9339.ivory1607.screen'

echo "== manifest permissions"
patch android/app/src/main/AndroidManifest.xml \
'android:name="android.permission.POST_NOTIFICATIONS" />' \
'android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />'

echo "== plaintext fallback"
patch android/app/src/main/java/com/you/life360monitor/RelayService.kt \
'val plain = Crypto.open(String(p)) ?: return' \
'val plain = Crypto.open(String(p)) ?: String(p)'

echo "== battery exemption prompt"
patch android/app/src/main/java/com/you/life360monitor/MainActivity.kt \
'requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1)' \
'requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1)
    try { startActivity(Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).setData(android.net.Uri.parse("package:" + packageName))) } catch (e: Exception) {}'

echo "== manifest url follows your repo"
patch .github/workflows/ios.yml \
'https://dunno-beep.github.io/life360-monitor/Life360-signed.ipa' \
'https://$GITHUB_REPOSITORY_OWNER.github.io/${GITHUB_REPOSITORY#*/}/Life360-signed.ipa'

echo "== publish url"
patch publish-ipa.sh '.assets[0].url' '.assets[0].browserDownloadUrl'

echo "== README diagram"
patch README.md \
'iPhone (agent) --ws + AES-GCM over Tailscale--> Relay --> Android (monitor)' \
'iPhone (agent) --wss + AES-GCM--> broker.emqx.io:8084 --> Android (monitor)
iPhone (agent) --optional--> relay :8080 --> browser dashboard'

echo
echo "$patched patches applied. REVIEW:"
git --no-pager diff --stat
echo
echo "read it:  git diff"
