buildscript {
    val kotlin_version by extra("1.9.23")

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin متوافق مع Gradle 8.9
        classpath("com.android.tools.build:gradle:8.9.1")
        // Kotlin Plugin موحد مع الإعدادات
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        // Google Services (Firebase)
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ضبط مجلد build في مكان واحد لتقليل استهلاك الرام
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}