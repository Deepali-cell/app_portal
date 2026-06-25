package com.tcbinfotech.tcb_portal

import com.tcbinfotech.tcb_portal.calldetect.CallDetectBridge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the local_auth plugin (biometrics).
class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val CALL_DETECT_CHANNEL = "tcb_portal/call_detect"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_DETECT_CHANNEL,
        )
        // Wire native → Flutter so the foreground service can push call
        // detection events up to the Dart side.
        CallDetectBridge.attach(channel)
        // Flutter → native handlers slot in here as Phase D.2 grows.
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success("pong")
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CallDetectBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
