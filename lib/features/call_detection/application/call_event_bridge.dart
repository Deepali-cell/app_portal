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
  /// Immediately upload it; AI processing runs server-side in the background.
  Future<void> _onRecordingFound(Map<String, dynamic> args) async {
    final path = (args['path'] ?? '').toString();
    final number = (args['number'] ?? '').toString();
    final folder = (args['folder'] ?? '').toString();
    if (path.isEmpty) return;

    _ref.read(recordingUploadProvider.notifier).set(
          RecordingUploadProgress(
              path: path, number: number, state: 'uploading'),
        );

    try {
      final repo = RecordingRepository(_ref.read(dioProvider));
      final r = await repo.upload(
        localPath: path,
        phoneNumber: number.isEmpty ? null : number,
        sourceFolder: folder.isEmpty ? null : folder,
      );
      _ref.read(recordingUploadProvider.notifier).set(
            RecordingUploadProgress(
              path: path,
              number: number,
              state: 'uploaded',
              recordingName: r.name,
            ),
          );
    } catch (e) {
      _ref.read(recordingUploadProvider.notifier).set(
            RecordingUploadProgress(
              path: path,
              number: number,
              state: 'failed',
              errorMessage: e.toString(),
            ),
          );
    }
  }
}

final callEventBridgeProvider = Provider<CallEventBridge>((ref) {
  final bridge = CallEventBridge(ref);
  bridge.start();
  return bridge;
});
