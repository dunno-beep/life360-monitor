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
