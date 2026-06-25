package com.tcbinfotech.tcb_portal.calldetect

import android.os.Environment
import android.util.Log
import java.io.File

/**
 * Phase D.2.4 — Reads the OEM-recorded call MP3 from the device's
 * native recorder folder. Different OEMs write to different paths:
 *
 *   * Samsung One UI: /storage/emulated/0/Recordings/Call/
 *                     or /storage/emulated/0/Sounds/Call/
 *   * Xiaomi/MIUI:    /storage/emulated/0/MIUI/sound_recorder/call_rec/
 *                     or /storage/emulated/0/Sounds/CallRecorder/
 *   * Realme/Oppo:    /storage/emulated/0/Music/Recordings/Call/
 *                     or /storage/emulated/0/Recordings/Call/
 *   * Vivo:           /storage/emulated/0/Record/Call/
 *                     or /storage/emulated/0/Music/Recordings/Call/
 *   * OnePlus:        /storage/emulated/0/Recordings/  (varies)
 *
 * Strategy: scan ALL known paths, pick the most-recently-modified audio
 * file whose mtime is within `windowSec` of the moment the call ended.
 * Returns null if no file found (user's phone doesn't record OR recorder
 * disabled OR no permission).
 */
object RecordingScanner {

    private const val TAG = "TcbRecordingScanner"

    private val KNOWN_FOLDERS = listOf(
        "Recordings/Call",
        "Sounds/Call",
        "Sounds/CallRecorder",
        "MIUI/sound_recorder/call_rec",
        "Music/Recordings/Call",
        "Record/Call",
        "Recordings",
        "Call recordings",
        "CallRecordings",
    )

    private val AUDIO_EXTS = setOf("mp3", "m4a", "amr", "wav", "aac", "ogg", "opus")

    data class Hit(
        val path: String,
        val mtimeMs: Long,
        val sizeBytes: Long,
        val folder: String,
    )

    /**
     * Find the latest recording newer than (now - windowSec) seconds.
     * Returns null if nothing matches.
     */
    fun findLatest(windowSec: Int = 60): Hit? {
        val root = Environment.getExternalStorageDirectory()
        if (root == null || !root.exists()) {
            Log.w(TAG, "External storage not accessible")
            return null
        }
        val cutoffMs = System.currentTimeMillis() - windowSec * 1000L

        var best: Hit? = null
        for (rel in KNOWN_FOLDERS) {
            val dir = File(root, rel)
            if (!dir.exists() || !dir.isDirectory) continue
            try {
                val files = dir.listFiles() ?: continue
                for (f in files) {
                    if (!f.isFile) continue
                    val ext = f.extension.lowercase()
                    if (ext !in AUDIO_EXTS) continue
                    if (f.lastModified() < cutoffMs) continue
                    if (best == null || f.lastModified() > best.mtimeMs) {
                        best = Hit(
                            path = f.absolutePath,
                            mtimeMs = f.lastModified(),
                            sizeBytes = f.length(),
                            folder = rel,
                        )
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Scan failed for $rel: ${e.message}")
            }
        }
        if (best != null) {
            Log.d(TAG, "Found recording: ${best.path} (${best.sizeBytes} bytes, folder=${best.folder})")
        } else {
            Log.d(TAG, "No recording found in any known folder in last ${windowSec}s")
        }
        return best
    }
}
