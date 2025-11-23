import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    // The Flutter Gradle Plugin must be applied before the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<JavaExec>("clean", {
    group = "build"
    description = "Deletes the build directory."
    mainClass.set("org.gradle.wrapper.GradleWrapperMain")
    args("clean")
})
