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
        buildConfigField("String", "RELAY", "\"100.64.x.y:8080\"")
        buildConfigField("String", "TOKEN", "\"b0d715b56f0e74e625e8fd3225e2baf19f6a6eb9edf99d46\"")
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
