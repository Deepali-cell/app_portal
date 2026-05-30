import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';
import '../../../shared/widgets/date_range_bar.dart';
import 'running_timer.dart';
import 'timer_sheets.dart';

final _dFmt = DateFormat('d MMM');
final _rangeFmt = DateFormat('d MMM yyyy');

class TimesheetScreen extends ConsumerWidget {
  const TimesheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timesheetControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Timesheet'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.read(timesheetControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Err(
          msg: e is ApiException ? e.message : 'Something went wrong.',
          onRetry: () =>
              ref.read(timesheetControllerProvider.notifier).reload(),
        ),
        data: (ctx) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(timesheetControllerProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.md,
                  AppDimens.screenPadding,
                  AppDimens.xl),
              children: [
                _Header(
                  title: 'Timesheet',
                  subtitle: 'Track time against tasks. Tap Start to begin.',
                  cta: ctx.activeTimer == null ? 'Start Timer' : 'Timer running…',
                  enabled: ctx.activeTimer == null,
                  onPressed: () => _open(context, ctx),
                ),
                if (ctx.activeTimer != null) ...[
                  const SizedBox(height: AppDimens.md),
                  RunningTimerCard(timer: ctx.activeTimer!),
                ],
                const SizedBox(height: AppDimens.md),
                DateRangeBar(
                  from: ctx.fromDate,
                  to: ctx.toDate,
                  onChanged: (f, t) =>
                      ref.read(timesheetControllerProvider.notifier).setRange(f, t),
                ),
                const SizedBox(height: AppDimens.md),
                if (ctx.timesheets.isEmpty)
                  _EmptyCard(
                    icon: Icons.access_time_outlined,
                    text:
                        'No timesheets between ${_rangeFmt.format(ctx.fromDate)} and ${_rangeFmt.format(ctx.toDate)}.',
                  )
                else ...[
                  _TotalsCard(ctx: ctx),
                  const SizedBox(height: AppDimens.md),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppDimens.md,
                              AppDimens.md,
                              AppDimens.md,
                              AppDimens.sm),
                          child: Text('Recent Entries',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                        ),
                        for (var i = 0; i < ctx.timesheets.length; i++) ...[
                          if (i > 0)
                            const Divider(
                                height: 1,
                                indent: 64,
                                color: AppColors.outlineVariant),
                          _TsRow(ts: ctx.timesheets[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, TimesheetContext ctx) async {
    if (ctx.activeTimer != null) return; // already running; tap card to stop
    if (ctx.projects.isEmpty || ctx.activityTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'You need an open project and an activity type to start a timer.')));
      return;
    }
    final ok = await showStartTimerSheet(context, ctx);
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Timer started.')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onPressed,
    this.enabled = true,
  });
  final String title;
  final String subtitle;
  final String cta;
  final bool enabled;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppDimens.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: Icon(enabled ? Icons.play_arrow : Icons.timer_outlined,
                size: 18),
            label: Text(cta),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryContainer,
              foregroundColor: AppColors.onSecondaryContainer,
              disabledBackgroundColor: AppColors.surfaceContainer,
              disabledForegroundColor: AppColors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.ctx});
  final TimesheetContext ctx;

  @override
  Widget build(BuildContext context) {
    final items = ctx.timesheets;
    final total = items.fold<double>(0, (s, t) => s + t.totalHours);
    final approved = items
        .where((t) => t.status.toLowerCase().contains('approved'))
        .fold<double>(0, (s, t) => s + t.totalHours);
    final draft = total - approved;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Logged hours · ${_rangeFmt.format(ctx.fromDate)} – ${_rangeFmt.format(ctx.toDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(_h(total),
              style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            Expanded(child: _kv(context, 'Approved', _h(approved))),
            Container(
                width: 1,
                height: 28,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(child: _kv(context, 'Pending / Draft', _h(draft))),
            Container(
                width: 1,
                height: 28,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(child: _kv(context, 'Entries', '${items.length}')),
          ]),
        ],
      ),
    );
  }

  String _h(double v) =>
      '${v == v.truncate() ? v.toInt() : v.toStringAsFixed(1)} h';

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 11)),
          const SizedBox(height: 2),
          Text(v,
              style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TsRow extends StatelessWidget {
  const _TsRow({required this.ts});
  final TimesheetSummary ts;
  @override
  Widget build(BuildContext context) {
    final period = (ts.startDate != null)
        ? '${_dFmt.format(ts.startDate!)}'
            '${ts.endDate != null && ts.endDate != ts.startDate ? ' – ${_dFmt.format(ts.endDate!)}' : ''}'
        : ts.name;
    return InkWell(
      onTap: () => context.push(Routes.timesheetDetail, extra: ts.name),
      child: Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.access_time_outlined,
                color: AppColors.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(period,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(ts.status,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
              '${ts.totalHours == ts.totalHours.truncate() ? ts.totalHours.toInt() : ts.totalHours.toStringAsFixed(1)} h',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            Icon(icon, color: AppColors.outline),
            const SizedBox(width: AppDimens.md),
            Expanded(
                child: Text(text,
                    style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppDimens.md),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
