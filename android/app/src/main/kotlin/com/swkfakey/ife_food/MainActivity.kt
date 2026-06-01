package com.swkfakey.ife_food

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_stripe exige FlutterFragmentActivity (et non FlutterActivity)
// pour présenter la PaymentSheet (qui utilise des fragments Android).
class MainActivity: FlutterFragmentActivity() {
}
