# R8 keep rules for the release build.
#
# Most of what this app depends on ships its own consumer rules inside its AAR —
# Firebase, Play Billing, google_mobile_ads and the Flutter engine all do — so
# this file only covers what those cannot know about.

# Flutter's deferred-components support references Play Core even when the app
# does not use deferred components, and R8 warns about the missing classes.
# Nothing here calls them, so the references are safe to drop.
-dontwarn com.google.android.play.core.**

# Plugins reach their Dart side through generated registrants and platform
# channels, both of which are found reflectively rather than by a call R8 can
# see. Losing them fails at runtime, not at build time.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# flutter_local_notifications deserialises scheduled notifications through Gson,
# so the field names in its model classes are load-bearing and must not be
# renamed. Its own rules cover the library; this covers the generic machinery.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }

# Crash reports are worth having line numbers in. The mapping file that makes
# them readable is written to build/app/outputs/mapping/release/ — upload it to
# Crashlytics and Play with each release, or the stack traces stay obfuscated.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
