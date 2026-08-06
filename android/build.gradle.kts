// Top-level build file where you can add configuration options common to all sub-projects/modules.
//
// IMPORTANT : le plugin `dev.flutter.flutter-plugin-loader` NE DOIT PAS être
// déclaré ici — il l'est dans settings.gradle.kts (au niveau Settings).
// Le déclarer ici provoque :
//   "class DefaultProject_Decorated cannot be cast to class Settings"
plugins {
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.10" apply false
}
