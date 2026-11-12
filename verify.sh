#!/usr/bin/env bash
cd "$(dirname "$0")"
fail=0
ck() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }

ck "Config has viewer"         "grep -q 'static let viewer' iphone/Config.swift"
ck "Config has control"        "grep -q 'static let control' iphone/Config.swift"
ck "topics use hashed ns"      "grep -q 'upTopic.*ns)' iphone/Config.swift"
ck "Crypto is v2 (HKDF)"       "grep -q HKDF iphone/Crypto.swift"
ck "tokens match both sides"   "[ \"\$(grep -oE '[a-f0-9]{48}' iphone/Config.swift | head -1)\" = \"\$(grep -oE '[a-f0-9]{48}' android/app/build.gradle.kts | head -1)\" ]"
ck "versionCode >= 7"          "[ \"\$(grep -oE 'versionCode = [0-9]+' android/app/build.gradle.kts | grep -oE '[0-9]+')\" -ge 7 ]"
ck "ext bundle id"             "grep -q 'ivory1607.screen' iphone/App.swift"
ck "storage perm"              "grep -q WRITE_EXTERNAL_STORAGE android/app/src/main/AndroidManifest.xml"
ck "battery perm"              "grep -q REQUEST_IGNORE_BATTERY_OPTIMIZATIONS android/app/src/main/AndroidManifest.xml"
ck "plaintext fallback"        "grep -q 'Crypto.open(String(p)) ?: String(p)' android/app/src/main/java/com/you/life360monitor/RelayService.kt"
ck "battery prompt"            "grep -q ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS android/app/src/main/java/com/you/life360monitor/MainActivity.kt"
ck "ios signs from secrets"    "grep -q SIGN_P12_B64 .github/workflows/ios.yml"
ck "pages step present"        "grep -q 'publish pages' .github/workflows/ios.yml"
ck "publish url fixed"         "grep -q browserDownloadUrl publish-ipa.sh"
ck "configure handles secrets" "grep -q 'VIEW=' configure.sh"
ck "no stray root ipa"         "[ ! -e Life360-signed.ipa ]"
ck "no stray version-ios.txt"  "[ ! -e version-ios.txt ]"
ck "not mid-rebase"            "[ ! -d .git/rebase-merge ] && [ ! -d .git/rebase-apply ]"

echo
[ "$fail" -eq 0 ] && echo "ALL GOOD" || echo "SOMETHING FAILED"
