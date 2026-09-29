import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../role_dashboards/data/role_dashboards_repository.dart';
import '../../role_dashboards/domain/models.dart';
import '../domain/module_flow.dart';
import 'flow_diagram.dart';
import 'module_dashboard_scaffold.dart';

/// HR module dashboard — the manager's morning overview: approvals waiting,
/// who is absent today, upcoming exits to plan for, and the birthdays to
/// remember this week. Reuses the existing HR summary endpoint + period
/// controller, matching the Projects and Finance dashboards.
class HrDashboardScreen extends ConsumerWidget {
  const HrDashboardScreen({super.key});

  static const _amber = Color(0xFFB54708);
  static const _red = Color(0xFFB42318);
  static const _blue = Color(0xFF2563EB);
  static const _green = Color(0xFF15803D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(hrPeriodProvider);
    final async = ref.watch(hrSummaryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('HR'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(hrSummaryProvider);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
            children: [
              const ModuleDashboardHeader(
                title: 'HR',
                subtitle: 'Approvals, attendance & people at a glance',
                icon: Icons.groups_outlined,
              ),
              const SizedBox(height: AppDimens.md),
              _PeriodChips(active: period),
              const SizedBox(height: AppDimens.md),
              async.when(
                loading: () => const FlowSkeleton(rows: 4),
                error: (e, _) => FlowLoadError(
                    message: e is ApiException
                        ? e.message
                        : "Couldn't load HR. Try again."),
                data: (s) => _Body(summary: s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChips extends ConsumerWidget {
  const _PeriodChips({required this.active});
  final RolePeriod active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final p in RolePeriod.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(hrPeriodProvider.notifier).set(p),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p == active
                      ? AppColors.primary
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(p.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p == active
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final HrSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionTitle('Today',
            subtitle: 'What needs the team\'s attention'),
        const SizedBox(height: AppDimens.sm),
        FlowDiagram(
          stages: [
            FlowStage(
              label: 'Pending Leaves',
              count: summary.pendingLeaveApps,
              icon: Icons.event_outlined,
              color: HrDashboardScreen._amber,
              route: Routes.approvals,
              hint: 'approve',
            ),
            FlowStage(
              label: 'Absent Today',
              count: summary.absentToday,
              icon: Icons.person_off_outlined,
              color: HrDashboardScreen._red,
              route: Routes.allAttendance,
              hint: 'follow up',
            ),
            FlowStage(
              label: 'Upcoming Exits',
              count: summary.upcomingExits,
              icon: Icons.logout_outlined,
              color: HrDashboardScreen._blue,
              route: Routes.directory,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.lg),
        DashboardSectionTitle(
          'Birthdays this week',
          subtitle: summary.birthdays.isEmpty
              ? 'No birthdays in the next 7 days'
              : 'A quick wish goes a long way',
        ),
        const SizedBox(height: AppDimens.sm),
        if (summary.birthdays.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, color: AppColors.onSurfaceVariant),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Text('Nothing coming up this week.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          )
        else
          for (final b in summary.birthdays) _BirthdayRow(item: b),
      ],
    );
  }
}

class _BirthdayRow extends StatelessWidget {
  const _BirthdayRow({required this.item});
  final HrBirthday item;

  String _when(int days) => switch (days) {
        0 => 'Today',
        1 => 'Tomorrow',
        _ => 'in $days days',
      };

  @override
  Widget build(BuildContext context) {
    final today = item.daysAway == 0;
    final tint = today ? HrDashboardScreen._green : HrDashboardScreen._blue;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(Icons.cake_outlined, size: 18, color: tint),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      item.employeeName.isEmpty
                          ? '(unnamed)'
                          : item.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (item.designation.isNotEmpty)
                    Text(item.designation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_when(item.daysAway),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: tint)),
            ),
          ],
        ),
      ),
    );
  }
}
