package com.tcbinfotech.tcb_portal

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.tcbinfotech.tcb_portal.calldetect.AllFilesAccessHelper
import com.tcbinfotech.tcb_portal.calldetect.CallDetectBridge
import com.tcbinfotech.tcb_portal.calldetect.LocalNotifier
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the local_auth plugin (biometrics).
class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val CALL_DETECT_CHANNEL = "tcb_portal/call_detect"
        const val DEEPLINK_EXTRA = "tcb.notif.deeplink"
    }

    // Most-recent deeplink received via Intent extra. Set on app cold-start +
    // every onNewIntent (warm tap from background). Flutter polls it on its
    // post-frame callback so we don't lose deeplinks fired before the
    // MethodChannel is alive.
    @Volatile
    private var pendingDeeplink: String? = null
    private var deeplinkChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture deeplink from the launch intent (cold-start case).
        val coldDeeplink = intent?.getStringExtra(DEEPLINK_EXTRA)
        Log.i("TcbDeeplink", "onCreate cold-start extra=$coldDeeplink")
        if (!coldDeeplink.isNullOrBlank()) {
            pendingDeeplink = coldDeeplink
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm-start: user tapped a notification while the app was already
        // running. Forward the extra to Flutter immediately if the channel
        // is alive; otherwise stash it for the next poll.
        setIntent(intent)
        val deeplink = intent.getStringExtra(DEEPLINK_EXTRA)
        Log.i("TcbDeeplink", "onNewIntent warm-tap extra=$deeplink channelAlive=${deeplinkChannel != null}")
        if (!deeplink.isNullOrBlank()) {
            pendingDeeplink = deeplink
            deeplinkChannel?.invokeMethod(
                "onDeeplink", mapOf("deeplink" to deeplink)
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_DETECT_CHANNEL,
        )
        deeplinkChannel = channel
        // Wire native → Flutter so the foreground service can push call
        // detection events up to the Dart side.
        CallDetectBridge.attach(channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success("pong")
                "hasAllFilesAccess" ->
                    result.success(AllFilesAccessHelper.hasAllFilesAccess())
                "openAllFilesAccessSettings" -> {
                    AllFilesAccessHelper.openAllFilesAccessSettings(this)
                    result.success(true)
                }
                "postLocalNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title") as? String ?: "TCB Portal"
                    val body = args?.get("body") as? String ?: ""
                    val deeplink = args?.get("deeplink") as? String
                    val id = (args?.get("id") as? Number)?.toInt()
                    val notifId = LocalNotifier.post(
                        context = this,
                        title = title,
                        body = body,
                        deeplink = deeplink,
                        notifId = id,
                    )
                    result.success(notifId)
                }
                "consumePendingDeeplink" -> {
                    val d = pendingDeeplink
                    pendingDeeplink = null
                    Log.i("TcbDeeplink", "consumePendingDeeplink → $d")
                    result.success(d)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CallDetectBridge.detach()
        deeplinkChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
