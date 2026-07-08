// build.gradle.kts (Root Level)
plugins {
    id("com.android.application") version "8.x.x" apply false
    id("com.android.library") version "8.x.x" apply false
    id("org.jetbrains.kotlin.android") version "1.x.x" apply false
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}