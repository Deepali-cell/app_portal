import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

enum CallEventKind { detected, ended }

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
        default:
          break;
      }
      return null;
    });
  }
}

final callEventBridgeProvider = Provider<CallEventBridge>((ref) {
  final bridge = CallEventBridge(ref);
  bridge.start();
  return bridge;
});
