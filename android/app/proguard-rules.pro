# ExoPlayer — évite le crash R8 sur exoplayer 2.x (bug de minification)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Stripe push provisioning (Apple/Google Pay "add to wallet") — module
# optionnel de react-native-stripe-sdk (dépendance transitive du plugin
# stripe), non utilisé par l'app. Classes absentes du classpath -> R8
# échoue sans ce -dontwarn (pas un vrai problème, code jamais exécuté).
-dontwarn com.reactnativestripesdk.pushprovisioning.**
-dontwarn com.stripe.android.pushProvisioning.**
