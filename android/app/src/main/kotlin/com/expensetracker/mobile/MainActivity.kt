package com.expensetracker.mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires the host Activity to be a FragmentActivity (it shows the biometric
// prompt via an androidx Fragment) — plain FlutterActivity doesn't satisfy that.
class MainActivity : FlutterFragmentActivity()
