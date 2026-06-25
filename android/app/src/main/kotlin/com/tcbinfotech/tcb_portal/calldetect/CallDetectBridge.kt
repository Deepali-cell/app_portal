package com.tcbinfotech.tcb_portal.calldetect

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Static singleton that lets the [CallDetectionService] (background) push
 * events up to the Flutter engine via a [MethodChannel].
 *
 * Wired by [MainActivity.configureFlutterEngine] on app start. When the app
 * is killed, [channel] is null and events fall on the floor — that's OK
 * because the notification posted by the service still reaches the user.
 *
 * Channel name: tcb_portal/call_detect
 *
 * Flutter-side methods invoked:
 *   onCallDetected   { "number": String, "direction": "incoming"|"outgoing" }
 *   onCallEnded      { "number": String? }
 *
 * Flutter → native (TODO in D.2.3+):
 *   isServiceRunning, dismissOverlay, openRecording(<path>)
 */
object CallDetectBridge {

    @Volatile
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    fun attach(c: MethodChannel) {
        channel = c
    }

    fun detach() {
        channel = null
    }

    fun emitCallDetected(number: String, direction: String) {
        post("onCallDetected", mapOf("number" to number, "direction" to direction))
    }

    fun emitCallEnded(number: String?) {
        post("onCallEnded", mapOf("number" to (number ?: "")))
    }

    private fun post(method: String, args: Map<String, Any?>) {
        // MethodChannel calls MUST happen on the main thread.
        main.post { channel?.invokeMethod(method, args) }
    }
}
