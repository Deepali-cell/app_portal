import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/attendance_controller.dart';
import '../data/attendance_repository.dart';
import '../domain/models.dart';

final _dayFmt = DateFormat('EEEE, MMMM d');
final _timeFmt = DateFormat('hh:mm a');
final _timeOnly = DateFormat('h:mm a');

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _mark(LogType type) async {
    // For IN: capture a selfie before anything else. Cancelling cancels the mark.
    String? selfiePath;
    if (type == LogType.inn) {
      final picker = ImagePicker();
      XFile? file;
      try {
        file = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 70,
          maxWidth: 1280,
        );
      } on Exception catch (e) {
        if (!mounted) return;
        _snack('Could not open the camera: $e');
        return;
      }
      if (file == null) {
        // User cancelled — do not proceed.
        return;
      }
      selfiePath = file.path;
    }

    setState(() => _marking = true);
    try {
      final result = await ref
          .read(attendanceControllerProvider.notifier)
          .mark(type, selfiePath: selfiePath);
      if (!mounted) return;
      _snack(result.status == MarkStatus.queued
          ? 'No connection — ${result.logType.label.toLowerCase()} saved and will sync.'
          : '${result.logType.label} recorded at ${result.matchedLocation}.');
    } on LocationException catch (e) {
      _snack(e.message);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityStatusProvider, (_, next) {
      final online =
          next.value?.any((r) => r != ConnectivityResult.none) ?? false;
      if (online) ref.read(attendanceControllerProvider.notifier).trySync();
    });

    final async = ref.watch(attendanceControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Time'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(attendanceControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Text(e is ApiException ? e.message : 'Something went wrong.',
                textAlign: TextAlign.center),
          ),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () =>
              ref.read(attendanceControllerProvider.notifier).reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.lg,
                AppDimens.screenPadding,
                AppDimens.lg),
            children: [
              _Header(now: _now),
              const SizedBox(height: AppDimens.lg),
              _ClockCard(
                state: state,
                marking: _marking,
                onMark: _mark,
              ),
              const SizedBox(height: AppDimens.lg),
              _WeekStrip(state: state),
              const SizedBox(height: AppDimens.md),
              _TodayStats(state: state),
              const SizedBox(height: AppDimens.lg),
              _RecentLogs(logs: state.context.todaysLogs),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_dayFmt.format(now),
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(_timeFmt.format(now),
            style: Theme.of(context).textTheme.displaySmall),
      ],
    );
  }
}

class _ClockCard extends ConsumerWidget {
  const _ClockCard({
    required this.state,
    required this.marking,
    required this.onMark,
  });
  final AttendanceState state;
  final bool marking;
  final ValueChanged<LogType> onMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = state.context.suggestedLogType;
    final canMark = state.canCheckIn && !marking;
    final inside = state.insideGeofence;
    final geofenceColor = state.locationError != null
        ? AppColors.warning
        : (inside ? AppColors.onTertiaryContainer : AppColors.error);
    String geofenceLabel;
    if (state.locationError != null) {
      geofenceLabel = '${state.locationError!} (tap to retry)';
    } else if (!state.hasLocation) {
      geofenceLabel = 'Locating…';
    } else if (inside) {
      geofenceLabel = state.nearest?.name ?? 'Within office';
    } else {
      geofenceLabel = state.nearest == null
          ? 'No offices configured'
          : '${state.distanceM?.round()} m from ${state.nearest!.name}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: AppDimens.lg),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => ref
                  .read(attendanceControllerProvider.notifier)
                  .refreshLocation(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16, color: geofenceColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(geofenceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.onSurface)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    type == LogType.inn
                        ? Icons.camera_alt_outlined
                        : Icons.gps_fixed,
                    size: 14,
                    color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                    type == LogType.inn
                        ? 'Selfie + location required'
                        : 'Location required',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: AppDimens.lg),
            // Big circular Clock-In/Out button.
            GestureDetector(
              onTap: canMark ? () => onMark(type) : null,
              child: Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.surfaceContainerHigh, width: 6),
                  color: AppColors.surface,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canMark
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.5),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: marking
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: AppColors.onPrimary))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type == LogType.inn
                                  ? Icons.touch_app
                                  : Icons.logout,
                              color: AppColors.onPrimary,
                              size: 38,
                            ),
                            const SizedBox(height: 6),
                            Text(type.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: AppColors.onPrimary,
                                        letterSpacing: 0.3)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(
                        state.context.todaysLogs.isEmpty
                            ? '—'
                            : _timeOnly.format(state.context.todaysLogs.last
                                .time
                                .toLocal()),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                  ],
                ),
                Container(
                    height: 32,
                    width: 1,
                    color: AppColors.outlineVariant),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Status',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(
                      canMark
                          ? 'Ready'
                          : (inside ? 'Working…' : 'Outside office'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: canMark
                                ? AppColors.onTertiaryContainer
                                : AppColors.warning,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (state.pendingCount > 0) ...[
              const SizedBox(height: AppDimens.md),
              _PendingChip(count: state.pendingCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_upload_outlined,
              size: 16, color: AppColors.onSecondaryFixed),
          const SizedBox(width: 6),
          Text('$count pending sync',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSecondaryFixed,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.state});
  final AttendanceState state;
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final logged = state.context.todaysLogs
        .map((l) => DateTime(l.time.year, l.time.month, l.time.day))
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppDimens.sm),
          child: Text('This Week',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final d in days) ...[
                _DayChip(
                  date: d,
                  isToday: _sameDay(d, today),
                  hasLog: logged.contains(DateTime(d.year, d.month, d.day)),
                  isFuture: d.isAfter(today),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.isToday,
    required this.hasLog,
    required this.isFuture,
  });
  final DateTime date;
  final bool isToday;
  final bool hasLog;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final dow = DateFormat('E').format(date).substring(0, 1);
    final day = date.day.toString();
    final bg = isToday
        ? AppColors.primary
        : (hasLog
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLowest);
    final fg = isToday ? AppColors.onPrimary : AppColors.onSurface;
    return Opacity(
      opacity: isFuture && !isToday ? 0.5 : 1,
      child: Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(
              color: isToday
                  ? Colors.transparent
                  : AppColors.outlineVariant.withValues(alpha: 0.5),
              width: 0.8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(dow,
                style: TextStyle(
                    color: isToday
                        ? AppColors.onPrimary.withValues(alpha: 0.8)
                        : AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(day,
                style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.state});
  final AttendanceState state;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.login_rounded,
            iconColor: AppColors.secondaryContainer,
            label: 'Logs today',
            value: '${state.context.todaysLogs.length}',
            trailing: const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: AppDimens.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.location_searching,
            iconColor: AppColors.onTertiaryContainer,
            label: 'Geofence',
            value: state.insideGeofence ? 'Inside' : 'Outside',
            trailing: Text(
              state.nearest == null
                  ? '—'
                  : '${state.distanceM?.round() ?? "?"} m',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.trailing,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget trailing;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RecentLogs extends StatelessWidget {
  const _RecentLogs({required this.logs});
  final List<Checkin> logs;
  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              const Icon(Icons.event_busy_outlined,
                  color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppDimens.md),
              Text('No check-ins today',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppDimens.sm),
          child: Text("Today's Logs",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < logs.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                _LogRow(log: logs[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final Checkin log;
  @override
  Widget build(BuildContext context) {
    final isIn = log.logType == LogType.inn;
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isIn ? Icons.login_rounded : Icons.logout_rounded,
              color: isIn ? AppColors.secondary : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.logType.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                Text(_timeOnly.format(log.time.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixedDim.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              border: Border.all(
                  color: AppColors.tertiaryFixedDim.withValues(alpha: 0.4)),
            ),
            child: Text('On Time',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onTertiaryFixedVariant,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
