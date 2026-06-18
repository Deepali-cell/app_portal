import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../timesheet/presentation/running_timer.dart';
import 'nav_destinations.dart';

/// Root shell. Mobile gets the horizontally-scrollable bottom nav; tablet/
/// desktop (>=840 px) gets a persistent side rail. Same destination list
/// drives both, role-gated by capability.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final dests = destinationsFor(profile);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _SideRail(dests: dests, currentRoute: _currentRoute(context)),
            VerticalDivider(width: 1, color: AppColors.outlineVariant),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RunningTimerStrip(),
          _ScrollableBottomNav(
              dests: dests, currentRoute: _currentRoute(context)),
        ],
      ),
    );
  }

  String _currentRoute(BuildContext context) =>
      GoRouterState.of(context).matchedLocation;
}

class _ScrollableBottomNav extends StatelessWidget {
  const _ScrollableBottomNav({required this.dests, required this.currentRoute});
  final List<NavDest> dests;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomNavHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final d in dests)
                  _BottomNavItem(
                    dest: d,
                    selected: isInBranch(d.route, currentRoute),
                    onTap: () {
                      if (!isInBranch(d.route, currentRoute)) {
                        context.go(d.route);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });
  final NavDest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: selected ? 14 : 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? dest.selectedIcon : dest.icon,
                size: 20,
                color: selected
                    ? AppColors.onSecondaryContainer
                    : AppColors.primaryFixedDim.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 1),
              Text(
                dest.label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.onSecondaryContainer
                      : AppColors.primaryFixedDim.withValues(alpha: 0.85),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.dests, required this.currentRoute});
  final List<NavDest> dests;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.sidebarWidth,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md, vertical: AppDimens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
                alignment: Alignment.center,
                child: Text('TCB',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.onPrimaryContainer)),
              ),
              const SizedBox(width: AppDimens.sm),
              Text('TCB Portal',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: AppDimens.xl),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final d in dests) _SideTile(dest: d, currentRoute: currentRoute),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({required this.dest, required this.currentRoute});
  final NavDest dest;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final selected = isInBranch(dest.route, currentRoute);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          if (!selected) context.go(dest.route);
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md, vertical: AppDimens.sm + 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryFixed : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(
                selected ? dest.selectedIcon : dest.icon,
                color: selected
                    ? AppColors.onSecondaryFixed
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.sm),
              Text(
                dest.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? AppColors.onSecondaryFixed
                          : AppColors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
