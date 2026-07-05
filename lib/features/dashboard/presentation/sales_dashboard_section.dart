import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../leads/application/leads_view_prefs.dart';
import '../data/dashboard_repository.dart';
import '../domain/models.dart';

/// Drop-in widget that renders the unified Sales Dashboard.
/// Placed on the Home screen between Welcome and the Bento grid.
///
/// 6 sections:
///   1. Scope toggle (My / Team) — managers only
///   2. Today snapshot (5 KPIs in a horizontal strip)
///   3. Follow-ups bucket (today / overdue / upcoming)
///   4. Status-wise Lead cards (one per CRM Lead Status)
///   5. Status-wise Deal cards (compact strip)
///   6. Recent AI summaries (last 5 Ready recordings)
class SalesDashboardSection extends ConsumerWidget {
  const SalesDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesDashboardProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimens.lg),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => _DashboardError(
        msg: e is ApiException
            ? e.message
            : "Couldn't load the sales dashboard.",
        onRetry: () => ref.invalidate(salesDashboardProvider),
      ),
      data: (d) => _DashboardBody(snapshot: d),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.snapshot});
  final SalesDashboard snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Non-CRM users see nothing here; the Home Bento grid handles them.
    if (!snapshot.canLead && !snapshot.canDeal) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.isManagerView) _ScopeToggle(scope: snapshot.scope),
        const SizedBox(height: AppDimens.md),
        _SectionHeader(
          title: 'Today',
          subtitle:
              "Live snapshot — refresh anytime",
        ),
        const SizedBox(height: 6),
        _TodayStrip(today: snapshot.today),
        const SizedBox(height: AppDimens.lg),
        if (snapshot.canLead) ...[
          _SectionHeader(
            title: 'Follow-ups',
            subtitle: snapshot.followups.dueToday > 0
                ? "${snapshot.followups.dueToday} due today — get on these first"
                : (snapshot.followups.overdue > 0
                    ? "${snapshot.followups.overdue} overdue — handle ASAP"
                    : "All caught up"),
          ),
          const SizedBox(height: 6),
          _FollowupsCard(bucket: snapshot.followups),
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.canLead && snapshot.leadStatuses.isNotEmpty) ...[
          _SectionHeader(
            title: 'Leads by status',
            subtitle:
                "${snapshot.leadStatuses.fold<int>(0, (a, b) => a + b.count)} total · tap a bucket to drill in",
          ),
          const SizedBox(height: 6),
          _StatusGrid(
              // Always show the two "action target" buckets — New (fresh
              // inbound) and Follow-up (rep-scheduled callback) — even
              // when empty. Both are places reps drop leads into, so the
              // card must exist for the drop target to be discoverable.
              // Other buckets hide at count 0 to keep the grid short.
              buckets: snapshot.leadStatuses.where((s) {
                if (s.count > 0) return true;
                final k = s.status.toLowerCase();
                return k == 'new' || k == 'follow-up';
              }).toList(),
              onTap: (s) {
                // Drill-in — set the pending status filter, then push
                // Leads. LeadsScreen reads + clears this on first build
                // so the list opens pre-filtered to the bucket's status.
                ref
                    .read(pendingLeadStatusFilterProvider.notifier)
                    .set(s.status);
                context.push(Routes.leads);
              }),
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.canDeal && snapshot.dealStatuses.isNotEmpty) ...[
          _SectionHeader(
            title: 'Deals by stage',
            subtitle:
                "${snapshot.dealStatuses.fold<int>(0, (a, b) => a + b.count)} total · tap to open Deals",
          ),
          const SizedBox(height: 6),
          _StatusGrid(
              buckets: snapshot.dealStatuses.where((s) => s.count > 0).toList(),
              onTap: (s) => context.push(Routes.deals)),
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.perRep.isNotEmpty) ...[
          _SectionHeader(
            title: 'Sales team today',
            subtitle:
                "${snapshot.perRep.length} reps · sorted by activity",
          ),
          const SizedBox(height: 6),
          for (final rep in snapshot.perRep) ...[
            _PerRepCard(rep: rep),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: AppDimens.lg),
        ],
        if (snapshot.recentSummaries.isNotEmpty) ...[
          _SectionHeader(
            title: 'AI summaries',
            subtitle: "Latest call analyses. Tap to view.",
          ),
          const SizedBox(height: 6),
          for (final s in snapshot.recentSummaries) ...[
            _SummaryCard(summary: s),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ScopeToggle extends ConsumerWidget {
  const _ScopeToggle({required this.scope});
  final String scope;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'mine', label: Text('My dashboard')),
        ButtonSegment(value: 'team', label: Text('Team dashboard')),
      ],
      selected: {scope},
      onSelectionChanged: (s) {
        ref.read(dashboardScopeProvider.notifier).set(s.first);
        ref.invalidate(salesDashboardProvider);
      },
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.today});
  final TodaySnapshot today;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _KpiTile(label: 'Calls', value: '${today.calls}', icon: Icons.call),
          const SizedBox(width: 8),
          _KpiTile(
              label: 'Connected',
              value: '${today.callsConnected}',
              icon: Icons.call_made),
          const SizedBox(width: 8),
          _KpiTile(
              label: 'New leads',
              value: '${today.leadsAdded}',
              icon: Icons.person_add_alt),
          const SizedBox(width: 8),
          _KpiTile(
              label: 'Tasks due',
              value: '${today.tasksDue}',
              icon: Icons.task_alt),
          const SizedBox(width: 8),
          _KpiTile(
              label: 'Won this month',
              value: moneyShort(today.monthWonValue),
              icon: Icons.emoji_events_outlined),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FollowupsCard extends StatelessWidget {
  const _FollowupsCard({required this.bucket});
  final FollowupsBucket bucket;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FollowupCell(
              label: 'Due today',
              value: bucket.dueToday,
              accent: AppColors.primary,
              icon: Icons.event_available,
            ),
          ),
          _Divider(),
          Expanded(
            child: _FollowupCell(
              label: 'Overdue',
              value: bucket.overdue,
              accent: const Color(0xFFB23A48),
              icon: Icons.warning_amber,
            ),
          ),
          _Divider(),
          Expanded(
            child: _FollowupCell(
              label: 'Next 7 days',
              value: bucket.upcomingWeek,
              accent: const Color(0xFFB87800),
              icon: Icons.schedule,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowupCell extends StatelessWidget {
  const _FollowupCell({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
  final String label;
  final int value;
  final Color accent;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(height: 4),
        Text('$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: accent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 48, color: AppColors.outlineVariant);
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.buckets, required this.onTap});
  final List<StatusBucket> buckets;
  final void Function(StatusBucket) onTap;
  @override
  Widget build(BuildContext context) {
    // 2-column grid with auto-sized rows.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Slightly less wide so the count + value row breathes vertically;
        // 2.1 was producing the cramped "₹10Cr crammed against bottom"
        // layout the user flagged.
        childAspectRatio: 2.1,
      ),
      itemCount: buckets.length,
      itemBuilder: (_, i) => _StatusCard(bucket: buckets[i], onTap: onTap),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.bucket, required this.onTap});
  final StatusBucket bucket;
  final void Function(StatusBucket) onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(bucket),
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md, vertical: 10),
        decoration: BoxDecoration(
          color: bucket.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: bucket.color.withValues(alpha: 0.30)),
        ),
        // Title row on top, count + value on a single bottom row with the
        // value right-aligned + muted so it reads as a secondary stat instead
        // of competing with the big count number for attention.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bucket.status,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: bucket.color,
                        fontWeight: FontWeight.w700,
                        height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (bucket.staleCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB23A48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${bucket.staleCount} stale',
                        style: const TextStyle(
                            color: Color(0xFFB23A48),
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${bucket.count}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: bucket.color,
                        fontWeight: FontWeight.w800,
                        height: 1.0)),
                if (bucket.value > 0) ...[
                  const Spacer(),
                  Text(moneyShort(bucket.value),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: bucket.color.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerRepCard extends StatelessWidget {
  const _PerRepCard({required this.rep});
  final PerRepCard rep;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.secondaryFixed,
            backgroundImage: (rep.image == null || rep.image!.isEmpty)
                ? null
                : NetworkImage(rep.image!),
            child: (rep.image == null || rep.image!.isEmpty)
                ? Text(rep.initials,
                    style: TextStyle(
                        color: AppColors.onSecondaryFixed,
                        fontWeight: FontWeight.w800))
                : null,
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rep.fullName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _RepStat(icon: Icons.person_search_outlined,
                        value: '${rep.leadsOwned}', label: 'leads'),
                    if (rep.leadsStale > 0)
                      _RepStat(
                          icon: Icons.error_outline,
                          value: '${rep.leadsStale}',
                          label: 'stale',
                          color: const Color(0xFFB23A48)),
                    _RepStat(icon: Icons.call,
                        value: '${rep.callsToday}', label: 'calls today'),
                    if (rep.tasksDue > 0)
                      _RepStat(icon: Icons.event_available,
                          value: '${rep.tasksDue}', label: 'due today'),
                    if (rep.tasksOverdue > 0)
                      _RepStat(icon: Icons.warning_amber,
                          value: '${rep.tasksOverdue}',
                          label: 'overdue',
                          color: const Color(0xFFB87800)),
                    if (rep.dealsWonMonth > 0)
                      _RepStat(icon: Icons.emoji_events_outlined,
                          value: '${rep.dealsWonMonth}',
                          label: 'won this month',
                          color: const Color(0xFF1B7F4D)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepStat extends StatelessWidget {
  const _RepStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 3),
      Text('$value ',
          style: TextStyle(
              color: c, fontWeight: FontWeight.w800, fontSize: 12)),
      Text(label,
          style: TextStyle(color: c, fontSize: 11)),
    ]);
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.summary});
  final RecentSummary summary;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      onTap: () {
        // Tap → open the linked lead/deal so the user lands on the
        // Calls tab where the full summary card is rendered.
        if (summary.referenceDoctype == 'Lead' &&
            summary.referenceDocname != null) {
          context.push(Routes.leadDetail, extra: summary.referenceDocname);
        } else if (summary.referenceDoctype == 'CRM Deal' &&
            summary.referenceDocname != null) {
          context.push(Routes.dealDetail, extra: summary.referenceDocname);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(summary.displayName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
              if (summary.suggestedStatus != null &&
                  summary.suggestedStatus!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('→ ${summary.suggestedStatus}',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            if (summary.summary != null && summary.summary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(summary.summary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.msg, required this.onRetry});
  final String msg;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppColors.onErrorContainer),
        const SizedBox(width: AppDimens.md),
        Expanded(
            child: Text(msg,
                style: TextStyle(color: AppColors.onErrorContainer))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}
