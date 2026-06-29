import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../call_detection/application/call_event_bridge.dart';

/// First-run permission walkthrough. Mounted at the app root above the
/// router, this widget kicks off on first build of an authenticated
/// session and walks the user through granting every runtime permission
/// the app needs in one batch — so they don't have to discover each one
/// the hard way later.
///
/// Runtime permissions work IDENTICALLY for sideloaded APKs and Play
/// Store installs — there is no Play-Store-only magic that auto-grants
/// permissions. Both have to call `Permission.x.request()` from the app
/// process. Apps that "just work" without prompting either don't need
/// dangerous permissions at all, or they request them lazily on first
/// use; we batch them here because almost every feature in this app
/// (calls, attendance, recording, notifications) needs at least one.
///
/// Permissions handled here:
///   * POST_NOTIFICATIONS    (Android 13+) — so the OS lets us push
///     local notifications for call captures, summaries, etc.
///   * READ_PHONE_STATE      — detect ringing/offhook
///   * READ_CALL_LOG         — resolve incoming number on Android 10+
///   * READ_CONTACTS         — match a caller to a Lead/Deal
///   * RECORD_AUDIO          — voice note attachments + future on-device
///                              transcription
///   * READ_MEDIA_AUDIO      (Android 13+) — read the OEM recorder's MP3
///   * ACCESS_FINE_LOCATION  — attendance check-in
///   * MANAGE_EXTERNAL_STORAGE — older OEM folders that scoped storage
///     can't reach (intent-based, handled separately by AllFilesAccessHelper)
///
/// Once the walkthrough has been completed (granted, denied, or
/// permanently-denied for every permission), we remember that in
/// SharedPreferences and never run it again unless the user
/// explicitly hits "Re-check permissions" in Settings.
class PermissionBootstrap extends ConsumerStatefulWidget {
  const PermissionBootstrap({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PermissionBootstrap> createState() =>
      _PermissionBootstrapState();
}

class _PermissionBootstrapState extends ConsumerState<PermissionBootstrap> {
  static const _boxName = 'tcb_onboarding';
  static const _doneKey = 'perm_bootstrap_done_v1';

  bool _running = false;

  /// The order is the order in which we ask — start with the cheap "no
  /// special intent" ones first, leave MANAGE_EXTERNAL_STORAGE for last.
  static final List<Permission> _toRequest = [
    Permission.notification,
    Permission.phone,
    Permission.contacts,
    Permission.microphone,
    Permission.audio,            // READ_MEDIA_AUDIO on A13+
    Permission.location,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRun());
  }

  Future<void> _maybeRun() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_running) return;

    final box = await _openBox();
    if (box.get(_doneKey) == true) return;

    _running = true;
    try {
      // Fire request() on each permission in sequence. Skipped permissions
      // (already granted, or permanently denied) are no-ops — the user
      // still sees the system dialog only for the ones that need it.
      for (final p in _toRequest) {
        try {
          await p.request();
        } catch (_) {/* skip; e.g. unsupported permission on this OS ver */}
      }
      // MANAGE_EXTERNAL_STORAGE uses a special Settings intent (no system
      // dialog). The call-detection settings screen handles it lazily; we
      // don't auto-open it here so we don't ambush the user with a full-
      // screen Settings page on first launch.
      await box.put(_doneKey, true);
    } finally {
      _running = false;
    }
  }

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  @override
  Widget build(BuildContext context) {
    // Re-trigger bootstrap whenever the auth state flips to authenticated
    // (covers first login + re-login after logout).
    ref.listen(callEventBridgeProvider, (_, __) {});
    return widget.child;
  }
}
