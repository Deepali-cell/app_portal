import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/recording_repository.dart';

/// Single event emitted from native (D.2.2 — Kotlin foreground service)
/// representing a phone-call state change observed on the device.
@immutable
class CallDetectEvent {
  const CallDetectEvent({
    required this.kind,
    required this.number,
    required this.direction,
    required this.at,
  });
  final CallEventKind kind;
  final String number;
  final String direction; // "incoming" | "outgoing" | ""
  final DateTime at;
}

enum CallEventKind { detected, ended, recordingFound, recordingUploaded, recordingFailed }

/// Latest recording-upload progress so the UI banner can show "Uploading…"
/// → "Uploaded, AI processing…" → "Ready" without each screen subscribing
/// to the bridge directly.
class RecordingUploadProgress {
  RecordingUploadProgress({
    required this.path,
    required this.number,
    required this.state,
    this.recordingName,
    this.errorMessage,
  });
  final String path;
  final String number;
  final String state; // 'uploading' | 'uploaded' | 'failed'
  final String? recordingName;
  final String? errorMessage;
}

class RecordingUploadController extends Notifier<RecordingUploadProgress?> {
  @override
  RecordingUploadProgress? build() => null;
  void set(RecordingUploadProgress p) => state = p;
}

final recordingUploadProvider =
    NotifierProvider<RecordingUploadController, RecordingUploadProgress?>(
        RecordingUploadController.new);

/// Holds the latest [CallDetectEvent] from the native module. Null until
/// the first event arrives. Any widget can `watch` for live updates.
class LastCallEventController extends Notifier<CallDetectEvent?> {
  @override
  CallDetectEvent? build() => null;
  void set(CallDetectEvent e) => state = e;
}

final lastCallEventProvider =
    NotifierProvider<LastCallEventController, CallDetectEvent?>(
        LastCallEventController.new);

/// Top-level service that owns the MethodChannel to native. Initialised once
/// in app startup. On every event from native, updates
/// [lastCallEventProvider] so any widget can listen.
class CallEventBridge {
  static const _channel = MethodChannel('tcb_portal/call_detect');

  CallEventBridge(this._ref);
  final Ref _ref;

  /// Native → Flutter: ask whether MANAGE_EXTERNAL_STORAGE is granted.
  /// Returns null on non-Android.
  Future<bool?> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system "All files access" Settings page for our package.
  Future<void> openAllFilesAccessSettings() async {
    try {
      await _channel.invokeMethod('openAllFilesAccessSettings');
    } catch (_) {/* swallow */}
  }

  /// Posts a system-tray notification via the native LocalNotifier. Used
  /// to surface call-capture + AI-summary alerts even when the app is
  /// backgrounded (the in-app banner only fires when the screen is open).
  Future<int?> postLocalNotification({
    required String title,
    required String body,
    String? deeplink,
    int? id,
  }) async {
    try {
      final r = await _channel.invokeMethod<int>('postLocalNotification', {
        'title': title,
        'body': body,
        if (deeplink != null) 'deeplink': deeplink,
        if (id != null) 'id': id,
      });
      return r;
    } catch (_) {
      return null;
    }
  }

  void start() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCallDetected':
          final args = (call.arguments as Map).cast<String, dynamic>();
          _ref.read(lastCallEventProvider.notifier).set(CallDetectEvent(
                kind: CallEventKind.detected,
                number: (args['number'] ?? '').toString(),
                direction: (args['direction'] ?? '').toString(),
                at: DateTime.now(),
              ));
          break;
        case 'onCallEnded':
          final args = (call.arguments as Map).cast<String, dynamic>();
          _ref.read(lastCallEventProvider.notifier).set(CallDetectEvent(
                kind: CallEventKind.ended,
                number: (args['number'] ?? '').toString(),
                direction: '',
                at: DateTime.now(),
              ));
          break;
        case 'onRecordingFound':
          final args = (call.arguments as Map).cast<String, dynamic>();
          _onRecordingFound(args);
          break;
        default:
          break;
      }
      return null;
    });
  }

  /// Native told us "here's the OEM-written MP3 for the call that just ended".
  /// Immediately upload + auto-create call log (server-side) + fire two
  /// local notifications: one when captured, one when AI summary is ready.
  Future<void> _onRecordingFound(Map<String, dynamic> args) async {
    final path = (args['path'] ?? '').toString();
    final number = (args['number'] ?? '').toString();
    final folder = (args['folder'] ?? '').toString();
    final direction = (args['direction'] ?? '').toString();
    final contactHint = (args['contact_name_hint'] ?? '').toString();
    if (path.isEmpty) return;

    _ref.read(recordingUploadProvider.notifier).set(
          RecordingUploadProgress(
              path: path, number: number, state: 'uploading'),
        );

    try {
      final repo = RecordingRepository(_ref.read(dioProvider));
      // Native sends "incoming" / "outgoing" lowercase; backend enum wants
      // "Incoming" / "Outgoing".
      final dirCapitalized = direction.isEmpty
          ? null
          : '${direction[0].toUpperCase()}${direction.substring(1).toLowerCase()}';
      final r = await repo.upload(
        localPath: path,
        phoneNumber: number.isEmpty ? null : number,
        sourceFolder: folder.isEmpty ? null : folder,
        direction: dirCapitalized,
        contactNameHint: contactHint.isEmpty ? null : contactHint,
      );
      _ref.read(recordingUploadProvider.notifier).set(
            RecordingUploadProgress(
              path: path,
              number: number,
              state: 'uploaded',
              recordingName: r.name,
            ),
          );

      // First notification: call captured (immediate, user-scoped).
      final captured = r.matchedDisplay?.isNotEmpty == true
          ? r.matchedDisplay!
          : (number.isEmpty ? "call" : number);
      await postLocalNotification(
        title: "Call captured: $captured",
        body: "AI summary processing — you'll be alerted when it's ready.",
        deeplink: "recording:${r.name}",
        id: r.name.hashCode & 0x7fffffff,
      );

      // Poll for AI readiness. 90 sec budget, every 5 sec.
      _pollForSummary(repo, r.name, displayHint: captured);
    } catch (e) {
      _ref.read(recordingUploadProvider.notifier).set(
            RecordingUploadProgress(
              path: path,
              number: number,
              state: 'failed',
              errorMessage: e.toString(),
            ),
          );
      await postLocalNotification(
        title: "Couldn't upload recording",
        body: "We saved the audio locally and will retry on next call.",
      );
    }
  }

  Future<void> _pollForSummary(
    RecordingRepository repo,
    String name, {
    required String displayHint,
  }) async {
    final repoStart = DateTime.now();
    while (DateTime.now().difference(repoStart).inSeconds < 90) {
      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        final fresh = await repo.get(name);
        if (fresh.isReady) {
          final suggest = fresh.suggestedStatus?.isNotEmpty == true
              ? " → ${fresh.suggestedStatus}"
              : "";
          await postLocalNotification(
            title: "AI summary ready: $displayHint",
            body: "Tap to view summary + suggested next action$suggest",
            deeplink: "recording:${fresh.name}",
            id: ("ready:${fresh.name}").hashCode & 0x7fffffff,
          );
          return;
        }
        if (fresh.isFailed) {
          await postLocalNotification(
            title: "AI processing failed: $displayHint",
            body: fresh.errorMessage ?? "Open the recording for details.",
            deeplink: "recording:${fresh.name}",
          );
          return;
        }
      } catch (_) {
        // Transient — keep polling.
      }
    }
    // 90s without Ready/Failed — leave it; next app-open the summary will
    // appear inline. No noisy timeout notification.
  }
}

final callEventBridgeProvider = Provider<CallEventBridge>((ref) {
  final bridge = CallEventBridge(ref);
  bridge.start();
  return bridge;
});
