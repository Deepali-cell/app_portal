import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/call_detect_controller.dart';
import '../application/call_event_bridge.dart';
import '../domain/permission_status.dart';

class CallDetectionScreen extends ConsumerStatefulWidget {
  const CallDetectionScreen({super.key});
  @override
  ConsumerState<CallDetectionScreen> createState() =>
      _CallDetectionScreenState();
}

class _CallDetectionScreenState extends ConsumerState<CallDetectionScreen> {
  bool _wizardRan = false;

  @override
  void initState() {
    super.initState();
    // Auto-request all ungranted permissions in sequence right after the
    // screen opens — addresses the "no permission popup" feedback.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPermissionWizard());
  }

  Future<void> _runPermissionWizard() async {
    if (_wizardRan) return;
    _wizardRan = true;
    if (kIsWeb || !Platform.isAndroid) return;

    final controller = ref.read(callDetectControllerProvider.notifier);
    final svc = ref.read(permissionServiceProvider);

    // Walk through each permission; request only the ungranted ones.
    for (final perm in CallDetectPermission.values) {
      final current = await svc.check(perm);
      if (current == PermissionState.granted ||
          current == PermissionState.notApplicable) {
        continue;
      }
      if (!mounted) return;
      // Brief explanation toast before each system dialog so user understands.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Permission needed: ${perm.label}'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await controller.requestPermission(perm);
      // Tiny pause so user sees each dialog cleanly.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    ref.invalidate(callDetectSnapshotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(callDetectSnapshotProvider);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Call detection'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(callDetectSnapshotProvider),
          ),
        ],
      ),
      body: !isAndroid
          ? const _IosNotice()
          : snap.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (s) => _AndroidBody(snapshot: s),
            ),
    );
  }
}

class _AndroidBody extends ConsumerWidget {
  const _AndroidBody({required this.snapshot});
  final CallDetectSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          AppDimens.md,
          AppDimens.screenPadding,
          AppDimens.xl),
      children: [
        _MasterToggle(enabled: snapshot.enabled),
        const SizedBox(height: AppDimens.md),
        const _LastCallBanner(),
        const SizedBox(height: AppDimens.md),
        const _UploadBanner(),
        const SizedBox(height: AppDimens.md),
        _DeviceSupportBanner(
          supported: snapshot.deviceSupported,
          hint: snapshot.deviceModelHint,
        ),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xs),
          child: Text(
            'Required permissions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppDimens.sm),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < snapshot.permissions.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      indent: 16,
                      color: AppColors.outlineVariant),
                _PermissionRow(status: snapshot.permissions[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimens.md),
        _FooterHint(),
      ],
    );
  }
}

/// Live banner that shows the last call detected by the native module —
/// the simplest visible confirmation that PhoneStateReceiver + service +
/// MethodChannel are all wired correctly.
class _LastCallBanner extends ConsumerWidget {
  const _LastCallBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(lastCallEventProvider);
    if (event == null) {
      return Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(children: [
          Icon(Icons.hourglass_empty,
              size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Text(
              'Make or receive a call to see live detection here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ]),
      );
    }
    final isEnd = event.kind == CallEventKind.ended;
    final title = isEnd
        ? 'Last call ended'
        : 'Detected ${event.direction.isEmpty ? "call" : event.direction} call';
    final body = event.number.isEmpty ? '(number unavailable)' : event.number;
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(isEnd ? Icons.call_end : Icons.ring_volume,
            color: AppColors.primary, size: 22),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Live banner showing recording upload state after the native scanner
/// finds the OEM-written MP3 and the bridge hands it off for upload.
class _UploadBanner extends ConsumerWidget {
  const _UploadBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(recordingUploadProvider);
    if (p == null) return const SizedBox.shrink();

    final Color color;
    final IconData icon;
    final String title;
    final String body;
    switch (p.state) {
      case 'uploading':
        color = AppColors.primary;
        icon = Icons.upload_outlined;
        title = 'Uploading recording…';
        body = p.path.split('/').last;
      case 'uploaded':
        color = const Color(0xFF1B7F4D);
        icon = Icons.cloud_done_outlined;
        title = 'Recording uploaded — AI summary processing';
        body = 'Tap to view once ready (~30s for a 2-min call).';
      case 'failed':
        color = const Color(0xFFB23A48);
        icon = Icons.error_outline;
        title = 'Recording upload failed';
        body = p.errorMessage ?? 'Try again from the lead detail later.';
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        if (p.state == 'uploading')
          const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, color: color, size: 22),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MasterToggle extends ConsumerWidget {
  const _MasterToggle({required this.enabled});
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: 8),
        child: SwitchListTile(
          value: enabled,
          onChanged: (v) =>
              ref.read(callDetectControllerProvider.notifier).setEnabled(v),
          title: Text('Enable call detection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
          subtitle: Text(
            enabled
                ? 'Active. Caller info will pop up on incoming calls and recordings will be captured.'
                : 'Off. Caller info popups and recording capture are disabled.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _DeviceSupportBanner extends StatelessWidget {
  const _DeviceSupportBanner({required this.supported, required this.hint});
  final bool supported;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final color =
        supported ? const Color(0xFF1B7F4D) : const Color(0xFFB87800);
    final icon = supported ? Icons.verified_outlined : Icons.warning_amber;
    final headline = supported
        ? 'This device should support call recording'
        : 'Limited support on this device';
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(hint,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({required this.status});
  final CallDetectStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (badgeColor, badgeText, badgeIcon) = _badge(status.state);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md, vertical: 6),
      title: Text(status.permission.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.onSurface, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(status.permission.rationale,
            style: Theme.of(context).textTheme.bodySmall),
      ),
      trailing: _trailingFor(context, ref, status, badgeColor, badgeText, badgeIcon),
      isThreeLine: true,
    );
  }

  Widget _trailingFor(BuildContext context, WidgetRef ref, CallDetectStatus s,
      Color badgeColor, String badgeText, IconData badgeIcon) {
    if (s.state == PermissionState.granted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(badgeIcon, color: badgeColor, size: 14),
          const SizedBox(width: 4),
          Text(badgeText,
              style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );
    }
    if (s.state == PermissionState.permanentlyDenied) {
      return TextButton(
        onPressed: () => ref
            .read(callDetectControllerProvider.notifier)
            .openSystemAppSettings(),
        child: const Text('Open Settings'),
      );
    }
    if (s.state == PermissionState.notApplicable) {
      return Text('—', style: TextStyle(color: AppColors.onSurfaceVariant));
    }
    return FilledButton(
      onPressed: () => ref
          .read(callDetectControllerProvider.notifier)
          .requestPermission(s.permission),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: const Text('Grant'),
    );
  }

  (Color, String, IconData) _badge(PermissionState s) {
    switch (s) {
      case PermissionState.granted:
        return (const Color(0xFF1B7F4D), 'Granted', Icons.check_circle);
      case PermissionState.denied:
        return (
          const Color(0xFFB87800),
          'Not granted',
          Icons.radio_button_unchecked
        );
      case PermissionState.permanentlyDenied:
        return (
          const Color(0xFFB23A48),
          'Blocked',
          Icons.block,
        );
      case PermissionState.notApplicable:
      case PermissionState.unknown:
        return (AppColors.outline, '—', Icons.help_outline);
    }
  }
}

class _FooterHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("One-time phone setup",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            "Even after the above permissions, you must enable your phone's "
            "built-in call recorder once:\n\n"
            "  • Open the Phone app (default dialer)\n"
            "  • Tap ⋮ menu → Settings → Record calls\n"
            "  • Toggle 'Record all calls' ON\n\n"
            "This is a one-time setup. We'll then auto-capture every call.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _IosNotice extends StatelessWidget {
  const _IosNotice();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Center(
        child: Card(
          color: AppColors.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline,
                    size: 36, color: AppColors.onSurfaceVariant),
                const SizedBox(height: 10),
                Text("Not available on iOS",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  "Apple's iOS sandbox prevents third-party apps from "
                  "intercepting phone calls or accessing call audio. "
                  "Manual call logging (post-call outcome sheet) continues "
                  "to work — open any lead and tap 'Log call' to capture "
                  "the call details.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
