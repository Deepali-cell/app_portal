package com.tcbinfotech.tcb_portal.calldetect

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.database.Cursor
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.CallLog
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.tcbinfotech.tcb_portal.MainActivity

/**
 * Foreground service that lives for the duration of a phone call. Responsible
 * for:
 *   1. Resolving the incoming/outgoing number (CallLog lookup with a 600ms
 *      delay because Android 10+ scrubs EXTRA_INCOMING_NUMBER from the
 *      broadcast).
 *   2. Notifying the Flutter side via [CallDetectBridge] so the app can call
 *      its lookup_by_phone backend and resolve the caller's CRM identity.
 *   3. Posting a foreground-service notification (visible while the call is
 *      active) — Android requires this for any service started outside an
 *      active UI context. Tap → opens the app.
 *   4. On call end (IDLE state), staying alive briefly so the
 *      recording-folder scan (D.2.4 — future) can pick up the OEM-written
 *      MP3 before the service is torn down.
 *
 * No overlay window yet — that's D.2.3.
 * No recording fetch yet — that's D.2.4.
 * No AI summary yet — that's D.2.5.
 *
 * This file is the D.2.2 minimum viable: detection + notification + Flutter
 * bridge.
 */
class CallDetectionService : Service() {

    companion object {
        private const val TAG = "TcbCallSvc"
        const val ACTION_RINGING = "tcb.call.RINGING"
        const val ACTION_OFFHOOK = "tcb.call.OFFHOOK"
        const val ACTION_IDLE = "tcb.call.IDLE"
        const val EXTRA_NUMBER = "tcb.call.number"

        private const val CHANNEL_ID = "tcb_call_detection"
        private const val FG_NOTIF_ID = 9101
        private const val EVENT_NOTIF_ID = 9102
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastNumber: String? = null
    // "incoming" if we ever saw RINGING for this call; "outgoing" otherwise.
    // OFFHOOK alone after IDLE → outgoing dial. RINGING then OFFHOOK → incoming pickup.
    private var lastDirection: String = "outgoing"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundCompat(buildIdleNotification("Listening for calls"))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_IDLE
        val incoming = intent?.getStringExtra(EXTRA_NUMBER)
        Log.d(TAG, "onStartCommand action=$action number=$incoming")

        when (action) {
            ACTION_RINGING -> handleRinging(incoming)
            ACTION_OFFHOOK -> handleOffhook()
            ACTION_IDLE -> handleIdle()
        }
        // Sticky so OS restarts us if killed mid-call.
        return START_STICKY
    }

    private fun handleRinging(numberFromIntent: String?) {
        lastDirection = "incoming"
        if (!numberFromIntent.isNullOrBlank()) {
            onNumberResolved(numberFromIntent, "incoming")
        } else {
            mainHandler.postDelayed({ resolveFromCallLog("incoming") }, 600)
        }
    }

    private fun handleOffhook() {
        // OFFHOOK fires for both outgoing dial and incoming pickup. CallLog
        // is usually written by now for outgoing.
        if (lastNumber == null) {
            // If we already marked incoming via RINGING, preserve that.
            mainHandler.postDelayed({ resolveFromCallLog(lastDirection) }, 600)
        }
    }

    private fun handleIdle() {
        val initialNumber = lastNumber
        // Emit the end event immediately so the UI knows the call wrapped.
        CallDetectBridge.emitCallEnded(initialNumber)
        updateIdleNotification("Last call: ${initialNumber ?: "…"} — resolving…")

        // CRITICAL: On Android 10+ the OS does NOT expose the dialed number
        // for OUTGOING calls via PHONE_STATE extras (privacy restriction).
        // The number lives only in CallLog, and CallLog's row for the just-
        // ended call is typically written at call termination. So we MUST
        // re-query CallLog AFTER IDLE — querying at OFFHOOK returns the
        // previous call's row (or nothing) and gives us the wrong number.
        //
        // Sequence after IDLE:
        //   t=0      emit end + update notif
        //   t=1.5s   re-query CallLog for the freshly-written current row
        //   t=3.5s   if still nothing, query again (some OEMs are slower)
        //   t=7s     scan OEM recorder folder for the MP3, dispatch upload
        //   t=20s    tear down the foreground service
        mainHandler.postDelayed({ refreshFromCallLogPostIdle(attempt = 1) }, 1_500)
        mainHandler.postDelayed({ refreshFromCallLogPostIdle(attempt = 2) }, 3_500)
        mainHandler.postDelayed({
            val numberAtCallEnd = lastNumber ?: initialNumber
            // Also emit the CALL_LOG event so Flutter can persist a CRM
            // Call Log row even when no recording is found (e.g. call
            // didn't connect, OEM doesn't write a recording, etc.).
            val (status, dur) = readLastCallStatusAndDuration()
            CallDetectBridge.emitCallLogReady(
                number = numberAtCallEnd,
                direction = lastDirection,
                status = status,
                durationSec = dur,
            )
            scanAndDispatch(numberAtCallEnd, retried = false)
        }, 7_000)
        mainHandler.postDelayed({ stopSelf() }, 20_000)
        lastNumber = null
    }

    /**
     * Re-read the most-recent CallLog row right after IDLE fires. Mutates
     * [lastNumber] in-place. Called twice on a delayed timer because Android
     * + OEM stack flush at different speeds.
     */
    private fun refreshFromCallLogPostIdle(attempt: Int) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED) return
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE,
                    CallLog.Calls.DURATION),
                null, null,
                "${CallLog.Calls.DATE} DESC LIMIT 1",
            )
            if (cursor != null && cursor.moveToFirst()) {
                val num = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER))
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                if (!num.isNullOrBlank()) {
                    lastNumber = num
                    // Refine direction if we didn't already know it.
                    val dir = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                        CallLog.Calls.MISSED_TYPE -> "incoming"
                        CallLog.Calls.REJECTED_TYPE -> "incoming"
                        else -> lastDirection
                    }
                    lastDirection = dir
                    Log.d(TAG, "post-idle CallLog (attempt=$attempt) → $num [$dir]")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "post-idle CallLog query failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
    }

    /**
     * Read the last call's terminal status (Completed / No answer / Busy /
     * Rejected) + duration from CallLog. Used to log a CRM Call Log even
     * when no recording is found — so the user has a record of every call
     * attempt, connected or not.
     */
    private fun readLastCallStatusAndDuration(): Pair<String, Int> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED) return "Completed" to 0
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.TYPE, CallLog.Calls.DURATION),
                null, null,
                "${CallLog.Calls.DATE} DESC LIMIT 1",
            )
            if (cursor != null && cursor.moveToFirst()) {
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                val dur = cursor.getLong(cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)).toInt()
                val status = when {
                    type == CallLog.Calls.MISSED_TYPE -> "No Answer"
                    type == CallLog.Calls.REJECTED_TYPE -> "Rejected"
                    type == CallLog.Calls.OUTGOING_TYPE && dur == 0 -> "No Answer"
                    type == CallLog.Calls.INCOMING_TYPE && dur == 0 -> "No Answer"
                    dur > 0 -> "Completed"
                    else -> "Completed"
                }
                return status to dur
            }
        } catch (e: Exception) {
            Log.e(TAG, "last-call status query failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
        return "Completed" to 0
    }

    private fun scanAndDispatch(numberAtCallEnd: String?, retried: Boolean) {
        val hit = RecordingScanner.findLatest(
            windowSec = if (retried) 120 else 60,
            hintNumber = numberAtCallEnd,
        )
        if (hit == null) {
            if (!retried) {
                // Try again after a longer write delay.
                mainHandler.postDelayed({ scanAndDispatch(numberAtCallEnd, retried = true) }, 5_000)
            } else {
                Log.d("TcbCallSvc", "No recording found after retry — phone may not be configured for built-in recording")
                updateIdleNotification("Last call: ${numberAtCallEnd ?: "—"} — no recording captured")
            }
            return
        }
        Log.d("TcbCallSvc", "Recording found: ${hit.path}  parsedContact=${hit.parsedContact}  parsedNumber=${hit.parsedNumber}")
        updateIdleNotification("Last call recording found — uploading…")
        // Fallback chain for number: live CallLog value → filename-parsed
        // number. If both empty, the parsed contact name (e.g. "Anuj Sharma")
        // still helps the backend lookup via CRM Lead.lead_name LIKE.
        val effectiveNumber = numberAtCallEnd.takeUnless { it.isNullOrBlank() }
            ?: hit.parsedNumber
        CallDetectBridge.emitRecordingFound(
            number = effectiveNumber,
            path = hit.path,
            sizeBytes = hit.sizeBytes,
            folder = hit.folder,
            mtimeMs = hit.mtimeMs,
            direction = lastDirection,
            contactNameHint = hit.parsedContact,
        )
        // Reset direction for the next call.
        lastDirection = "outgoing"
    }

    private fun resolveFromCallLog(direction: String) {
        // Need READ_CALL_LOG. If absent, nothing to do.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "READ_CALL_LOG denied — cannot resolve number")
            return
        }
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE),
                null,
                null,
                "${CallLog.Calls.DATE} DESC LIMIT 1",
            )
            if (cursor != null && cursor.moveToFirst()) {
                val numIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val num = cursor.getString(numIdx)
                if (!num.isNullOrBlank()) {
                    onNumberResolved(num, direction)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "CallLog query failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
    }

    private fun onNumberResolved(number: String, direction: String) {
        lastNumber = number
        Log.d(TAG, "Resolved number: $number ($direction)")
        // Tell Flutter so it can hit lookup_by_phone + render caller card.
        CallDetectBridge.emitCallDetected(number, direction)
        // Post a separate event notification (visible even if app is closed).
        showCallerNotification(number, direction)
    }

    // ---------- Notifications ----------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Call Detection",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Background service that watches for calls and captures recordings."
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildIdleNotification(text: String): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TCB Portal — Call Detection")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_notify_call_mute)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateIdleNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(FG_NOTIF_ID, buildIdleNotification(text))
    }

    private fun showCallerNotification(number: String, direction: String) {
        val openApp = PendingIntent.getActivity(
            this, 1,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("tcb.call.deeplink", "lookup:$number")
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = if (direction == "incoming") "Incoming call: $number" else "Outgoing call: $number"
        val body = "Tap to open in TCB Portal and view CRM context."
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_notify_call_mute)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build()
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(EVENT_NOTIF_ID, notif)
    }

    private fun startForegroundCompat(notif: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ requires explicit foregroundServiceType.
            // FOREGROUND_SERVICE_TYPE_SPECIAL_USE is acceptable for our case
            // (no narrower type fits — we're not a dialer or media app).
            startForeground(
                FG_NOTIF_ID, notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(FG_NOTIF_ID, notif)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")
        super.onDestroy()
    }
}
