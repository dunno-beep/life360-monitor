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
        versionCode = 9
        versionName = "1.0"
        buildConfigField("String", "RELAY", "\"100.94.117.23:8080\"")
        buildConfigField("String", "TOKEN", "\"f6ab49d305655e5b85d5384e0cfe03dcbc04b64c06c4fb1e\"")
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
