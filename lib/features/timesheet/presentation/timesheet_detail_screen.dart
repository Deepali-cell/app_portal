import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _dtFmt = DateFormat('d MMM, h:mm a');

class TimesheetDetailScreen extends ConsumerStatefulWidget {
  const TimesheetDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<TimesheetDetailScreen> createState() =>
      _TimesheetDetailScreenState();
}

class _TimesheetDetailScreenState extends ConsumerState<TimesheetDetailScreen> {
  bool _submitting = false;

  Future<void> _submit(TimesheetDetail d) async {
    if (d.hasActiveTimer) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stop the running timer before submitting.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit timesheet?'),
        content: Text(
            'This will submit ${d.name}. Once submitted you cannot edit its entries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(timesheetControllerProvider.notifier)
          .submitTimesheet(widget.name);
      ref.invalidate(timesheetDetailProvider(widget.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${d.name} submitted.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(timesheetDetailProvider(widget.name));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Timesheet'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () =>
                ref.invalidate(timesheetDetailProvider(widget.name)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.xl),
            child: Text(
              e is ApiException ? e.message : 'Could not open the timesheet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
              AppDimens.lg, AppDimens.screenPadding, AppDimens.xl),
          children: [
            _Hero(d: d),
            const SizedBox(height: AppDimens.lg),
            _LogsSection(logs: d.logs),
            if (d.note != null && d.note!.isNotEmpty) ...[
              const SizedBox(height: AppDimens.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppDimens.sm),
                      Text(d.note!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: async.when(
        loading: () => null,
        error: (_, _) => null,
        data: (d) {
          if (!d.isDraft) return null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                  AppDimens.sm, AppDimens.screenPadding, AppDimens.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.hasActiveTimer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.sm),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              'Stop the running timer before submitting.',
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ),
                      ]),
                    )
                  else if (!d.canSubmit)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.sm),
                      child: Text(
                          'You do not have permission to submit this timesheet.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Submit'),
                      onPressed: (_submitting ||
                              d.hasActiveTimer ||
                              !d.canSubmit)
                          ? null
                          : () => _submit(d),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryContainer,
                        disabledBackgroundColor: AppColors.surfaceContainer,
                        disabledForegroundColor:
                            AppColors.onSurfaceVariant,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusLg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.d});
  final TimesheetDetail d;

  String _formatHours(double v) =>
      v == v.truncate() ? '${v.toInt()} h' : '${v.toStringAsFixed(1)} h';

  String _docstatusLabel(int s) =>
      switch (s) { 1 => 'Submitted', 2 => 'Cancelled', _ => 'Draft' };

  @override
  Widget build(BuildContext context) {
    final period = (d.startDate != null && d.endDate != null)
        ? '${_dateFmt.format(d.startDate!)} – ${_dateFmt.format(d.endDate!)}'
        : d.name;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.name,
              style: TextStyle(
                  color: AppColors.primaryFixedDim, fontSize: 12)),
          const SizedBox(height: 4),
          Text(period,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppDimens.md),
          Row(children: [
            Expanded(child: _kv(context, 'Total', _formatHours(d.totalHours))),
            Container(
                width: 1,
                height: 32,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(
                child:
                    _kv(context, 'Status', d.status.isEmpty ? '-' : d.status)),
            Container(
                width: 1,
                height: 32,
                color: AppColors.primaryFixedDim.withValues(alpha: 0.25)),
            Expanded(
                child: _kv(context, 'State', _docstatusLabel(d.docstatus))),
          ]),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style:
                  TextStyle(color: AppColors.primaryFixedDim, fontSize: 11)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.logs});
  final List<TimesheetLogRow> logs;

  String _h(double v) =>
      v == v.truncate() ? '${v.toInt()} h' : '${v.toStringAsFixed(1)} h';

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined,
                  color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppDimens.md),
              Expanded(
                  child: Text('No time logs on this timesheet.',
                      style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Time logs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${logs.length}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, indent: 64, color: AppColors.outlineVariant),
            _LogRow(log: logs[i], hours: _h(logs[i].hours)),
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.hours});
  final TimesheetLogRow log;
  final String hours;

  @override
  Widget build(BuildContext context) {
    final title = log.activityType ?? 'Time log';
    final meta = [
      if (log.project != null && log.project!.isNotEmpty) log.project,
      if (log.task != null && log.task!.isNotEmpty) log.task,
    ].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.access_time_outlined,
                color: AppColors.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                if (log.fromTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                      '${_dtFmt.format(log.fromTime!.toLocal())}'
                      '${log.toTime != null ? " → ${_dtFmt.format(log.toTime!.toLocal())}" : ""}',
                      style: Theme.of(context).textTheme.labelSmall),
                ],
                if (log.description != null &&
                    log.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(log.description!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Text(hours,
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
