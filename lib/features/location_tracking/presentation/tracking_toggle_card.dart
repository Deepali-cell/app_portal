import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/location_bridge.dart';
import '../data/location_tracking_repository.dart';

/// Home-screen card that lets the user turn tracking ON / OFF. Shows the
/// "sharing since HH:mm" line + last ping timestamp so people know it works.
class TrackingToggleCard extends ConsumerWidget {
  const TrackingToggleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trackingStatusProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: async.when(
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Text('Tracking status unavailable',
              style: TextStyle(color: AppColors.onSurfaceVariant)),
          data: (status) => _Body(status: status),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.status});
  final dynamic status; // TrackingStatus
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Future<void> _flip(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = on
        ? await enableTrackingFlow(ref)
        : await disableTrackingFlow(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final on = s.enabled == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: on ? AppColors.tertiaryFixed : AppColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            on ? Icons.location_on : Icons.location_off_outlined,
            size: 22,
            color: on
                ? AppColors.onTertiaryFixedVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                on ? 'Sharing location' : 'Location sharing off',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                on ? _onSubtitle(s) : "Turn on to let your manager see where you are.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: on,
                onChanged: (v) => _flip(v),
                activeThumbColor: AppColors.primary,
              ),
      ],
    );
  }

  String _onSubtitle(dynamic s) {
    final buf = StringBuffer();
    if (s.startedAt != null) {
      buf.write('On since ${DateFormat('HH:mm').format(s.startedAt)}');
    }
    if (s.lastPingAt != null) {
      if (buf.isNotEmpty) buf.write('. ');
      buf.write('Last update ${DateFormat('HH:mm').format(s.lastPingAt)}');
    }
    if (buf.isEmpty) return 'Tracking active.';
    return buf.toString();
  }
}
