# ExoPlayer — évite le crash R8 sur exoplayer 2.x (bug de minification)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
