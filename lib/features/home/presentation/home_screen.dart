import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/money.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/domain/models.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../leave/application/leave_controller.dart';
import '../../leave/domain/models.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../payslips/application/payslip_controller.dart';
import '../../todays_plan/presentation/todays_plan_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _HomeAppBar(profile: profile),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding, AppDimens.md, AppDimens.screenPadding,
              AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WelcomeHero(profile: profile),
              if (profile.can('crm_lead')) ...[
                const SizedBox(height: AppDimens.lg),
                const TodaysPlanCard(),
              ],
              if (profile.can('crm_lead') || profile.can('crm_deal')) ...[
                const SizedBox(height: AppDimens.lg),
                const _PipelineEntry(),
              ],
              if (profile.can('manager_view')) ...[
                const SizedBox(height: AppDimens.lg),
                const _LeaderboardEntry(),
                const SizedBox(height: AppDimens.lg),
                const _TeamStatusEntry(),
              ],
              const SizedBox(height: AppDimens.lg),
              const _BentoGrid(),
              const SizedBox(height: AppDimens.lg),
              const _RecentActivity(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.profile});
  final Profile profile;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppColors.surfaceContainerLowest,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: AppDimens.screenPadding,
      title: Row(
        children: [
          InkWell(
            onTap: () => context.push(Routes.profile),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(profile.initials,
                    style: TextStyle(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Text('TCB Portal',
              style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      actions: [
        Consumer(builder: (context, ref, _) {
          final unread = ref.watch(unreadCountProvider).value ?? 0;
          return IconButton(
            onPressed: () => context.push(Routes.notifications),
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined,
                    color: AppColors.primary),
                if (unread > 0)
                  Positioned(
                    right: -4,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.surfaceContainerLowest,
                            width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        IconButton(
          onPressed: () => _confirmSignOut(context, ref),
          tooltip: 'Sign out',
          icon: Icon(Icons.logout, color: AppColors.primary),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will need to sign in again to access the portal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}


class _WelcomeHero extends ConsumerWidget {
  const _WelcomeHero({required this.profile});
  final Profile profile;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName =
        profile.fullName.split(' ').first;
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -36,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryFixedDim.withValues(alpha: 0.35),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, $firstName!',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 2),
              Text("Here's what's happening today.",
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppDimens.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(Routes.time),
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Clock In'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go(Routes.leave),
                      icon: const Icon(Icons.event_available_outlined,
                          size: 18),
                      label: const Text('Apply Leave'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BentoGrid extends ConsumerWidget {
  const _BentoGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _ShiftCard(),
        SizedBox(height: AppDimens.md),
        _LeaveBalanceCard(),
        SizedBox(height: AppDimens.md),
        _LastPayslipCard(),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

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
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.secondary, size: 18),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends ConsumerWidget {
  const _ShiftCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendanceControllerProvider);
    return _BentoCard(
      title: 'Today',
      icon: Icons.schedule,
      child: async.when(
        loading: () => const _SkeletonLine(),
        error: (_, _) => Text('Open the Time tab to check in.',
            style: Theme.of(context).textTheme.bodyMedium),
        data: (s) {
          final todays = s.context.todaysLogs;
          if (todays.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You haven't checked in yet.",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text('Suggested: ${s.context.suggestedLogType.label}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
          }
          final last = todays.last;
          final fmt = DateFormat('h:mm a');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Last ${last.logType.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(fmt.format(last.time.toLocal()),
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          );
        },
      ),
    );
  }
}

class _LeaveBalanceCard extends ConsumerWidget {
  const _LeaveBalanceCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveControllerProvider);
    return _BentoCard(
      title: 'Leave Balance',
      icon: Icons.flight_takeoff_outlined,
      child: async.when(
        loading: () => const _SkeletonLine(),
        error: (_, _) => Text('No leave data yet.',
            style: Theme.of(context).textTheme.bodyMedium),
        data: (ctx) {
          if (ctx.balances.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No allocations yet',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text('Open the Leave tab to apply.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
          }
          // Show the leave type with the most remaining as the headline.
          final top = (List<LeaveBalance>.from(ctx.balances)
                ..sort((a, b) => b.remaining.compareTo(a.remaining)))
              .first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_n(top.remaining),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 4),
                  Text(' days left',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 6),
              if (top.total > 0)
                LinearProgressIndicator(
                  value: (top.remaining / top.total).clamp(0, 1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: AppColors.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation(
                      AppColors.secondaryContainer),
                ),
              const SizedBox(height: 6),
              Text(top.leaveType,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          );
        },
      ),
    );
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _LastPayslipCard extends ConsumerStatefulWidget {
  const _LastPayslipCard();
  @override
  ConsumerState<_LastPayslipCard> createState() => _LastPayslipCardState();
}

class _LastPayslipCardState extends ConsumerState<_LastPayslipCard> {
  bool _revealed = false;
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payslipListProvider);
    return _BentoCard(
      title: 'Last Payslip',
      icon: Icons.payments_outlined,
      child: async.when(
        loading: () => const _SkeletonLine(),
        error: (_, _) => Text('Could not load payslips.',
            style: Theme.of(context).textTheme.bodyMedium),
        data: (ctx) {
          if (ctx.slips.isEmpty) {
            return Text('No payslips yet.',
                style: Theme.of(context).textTheme.bodyMedium);
          }
          final last = ctx.slips.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('d MMM yyyy').format(last.endDate),
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.tertiaryFixedDim, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        _revealed ? money(last.net, last.currency) : '••••••',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: _revealed ? 'Hide' : 'Show',
                    icon: Icon(
                        _revealed
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () => setState(() => _revealed = !_revealed),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceControllerProvider);
    final leave = ref.watch(leaveControllerProvider);

    final items = <_ActivityItem>[];

    attendance.whenData((s) {
      for (final log in s.context.todaysLogs.reversed) {
        items.add(_ActivityItem(
          icon: log.logType == LogType.inn
              ? Icons.login_rounded
              : Icons.logout_rounded,
          color: AppColors.secondary,
          tone: AppColors.secondaryFixed,
          title: log.logType == LogType.inn ? 'Checked in' : 'Checked out',
          subtitle: DateFormat('h:mm a').format(log.time.toLocal()),
          when: log.time,
        ));
      }
    });

    leave.whenData((ctx) {
      for (final a in ctx.applications.take(3)) {
        items.add(_ActivityItem(
          icon: Icons.calendar_month,
          color: AppColors.primary,
          tone: AppColors.secondaryFixed,
          title: 'Leave ${_statusVerb(a.status)}',
          subtitle:
              '${a.leaveType} · ${DateFormat('d MMM').format(a.fromDate)}'
              '${a.fromDate == a.toDate ? "" : " – ${DateFormat('d MMM').format(a.toDate)}"}',
          when: a.fromDate,
        ));
      }
    });

    items.sort((a, b) => b.when.compareTo(a.when));
    final top = items.take(5).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.md, AppDimens.md, AppDimens.md, AppDimens.sm),
            child: Text('Recent Activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.md, 0, AppDimens.md, AppDimens.md),
              child: Text('Nothing here yet.',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...top.map((it) => _ActivityRow(item: it)),
        ],
      ),
    );
  }

  String _statusVerb(LeaveStatus s) {
    switch (s) {
      case LeaveStatus.approved:
        return 'approved';
      case LeaveStatus.rejected:
        return 'rejected';
      case LeaveStatus.cancelled:
        return 'cancelled';
      case LeaveStatus.open:
        return 'submitted';
    }
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.when,
  });
  final IconData icon;
  final Color color;
  final Color tone;
  final String title;
  final String subtitle;
  final DateTime when;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final _ActivityItem item;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 0.4)),
      ),
      padding: const EdgeInsets.all(AppDimens.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.tone,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500)),
                Text(item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(_relative(item.when),
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Compact CTA on the home that opens the CRM Pipeline / Funnel screen.
/// Gated upstream by `crm_lead OR crm_deal` capability — non-CRM users
/// never see this card.
class _PipelineEntry extends StatelessWidget {
  const _PipelineEntry();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: () => context.push(Routes.pipeline),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.insights_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pipeline",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      "Funnel view — kaunsi leads / deals kaunsi stage me hain",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact CTA on the home that opens the live Team Status dashboard.
/// Gated upstream by `manager_view` capability.
class _TeamStatusEntry extends StatelessWidget {
  const _TeamStatusEntry();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: () => context.push(Routes.teamStatus),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.groups_2_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Team status",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      "Live — kaun online hai, kisne kitne calls kiye aaj",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact CTA on the home that takes managers into the leaderboard screen.
class _LeaderboardEntry extends StatelessWidget {
  const _LeaderboardEntry();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        onTap: () => context.push(Routes.leaderboard),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.emoji_events_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Leaderboard",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      "Team performance for this month — tap to drill in",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
