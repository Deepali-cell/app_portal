import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../application/call_event_bridge.dart';
import '../data/recording_repository.dart';

/// Mounted at the app root. Watches [pendingDeeplinkProvider] for any
/// deeplink string published by the native notification system and routes
/// the user accordingly.
///
/// Deeplink format: "kind:identifier"
///   * `lead:CRM-LEAD-2026-00050`      → /lead-detail extra=name
///   * `deal:CRM-DEAL-...`             → /deal-detail extra=name
///   * "recording:CALL-REC-2026-..."   → fetch the recording, navigate to
///                                        its linked Lead/Deal (Calls tab
///                                        renders the summary card)
///
/// Cold-start path: native cached any deeplink that arrived before the
/// MethodChannel was alive; we consume it once on first frame.
class DeeplinkListener extends ConsumerStatefulWidget {
  const DeeplinkListener({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<DeeplinkListener> createState() => _DeeplinkListenerState();
}

class _DeeplinkListenerState extends ConsumerState<DeeplinkListener> {
  bool _coldChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_coldChecked) return;
      _coldChecked = true;
      final cold = await ref.read(callEventBridgeProvider).consumePendingDeeplink();
      if (cold != null && cold.isNotEmpty) {
        ref.read(pendingDeeplinkProvider.notifier).set(cold);
      }
    });
  }

  Future<void> _handle(String deeplink) async {
    // Clear immediately so we don't loop or double-fire.
    ref.read(pendingDeeplinkProvider.notifier).clear();

    final idx = deeplink.indexOf(':');
    if (idx <= 0) return;
    final kind = deeplink.substring(0, idx).toLowerCase();
    final id = deeplink.substring(idx + 1).trim();
    if (id.isEmpty) return;

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    switch (kind) {
      case 'lead':
        ctx.push(Routes.leadDetail, extra: id);
        break;
      case 'deal':
        ctx.push(Routes.dealDetail, extra: id);
        break;
      case 'recording':
        await _openRecording(ctx, id);
        break;
      default:
        break;
    }
  }

  Future<void> _openRecording(BuildContext ctx, String recordingName) async {
    try {
      final repo = RecordingRepository(ref.read(dioProvider));
      final rec = await repo.get(recordingName);
      final dt = rec.referenceDoctype;
      final dn = rec.referenceDocname;
      if (dt == null || dn == null || dn.isEmpty) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Recording $recordingName — no linked lead/deal'),
          ));
        }
        return;
      }
      if (!ctx.mounted) return;
      if (dt == 'Lead') {
        ctx.push(Routes.leadDetail, extra: dn);
      } else if (dt == 'CRM Deal') {
        ctx.push(Routes.dealDetail, extra: dn);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text("Couldn't open recording: $e"),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingDeeplinkProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handle(next));
      }
    });
    return widget.child;
  }
}
