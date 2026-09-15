import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/admin_controller.dart';
import '../domain/models.dart';

/// In-app Administrator: pick a role, toggle its real Frappe permissions per
/// screen. Writes go straight to Custom DocPerm - no parallel config. Visible
/// only to System Manager (nav gated by the `admin` capability).
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String? _role;

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(adminMetaProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Administrator')),
      body: metaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (meta) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined),
                  const SizedBox(width: AppDimens.sm),
                  const Text('Role:'),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _role,
                      hint: const Text('Select a role'),
                      items: meta.roles
                          .map((r) =>
                              DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _role = v);
                        ref.read(roleMatrixProvider.notifier).load(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _role == null
                  ? const Center(
                      child: Text('Pick a role to configure its screens'))
                  : _RoleMatrix(modules: meta.modules),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleMatrix extends ConsumerWidget {
  const _RoleMatrix({required this.modules});
  final List<AdminModule> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roleMatrixProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text('$e', textAlign: TextAlign.center),
        ),
      ),
      data: (matrix) => ListView(
        children: [
          for (final m in modules)
            ExpansionTile(
              title: Text(m.module,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              childrenPadding: const EdgeInsets.only(bottom: AppDimens.sm),
              children: [
                for (final s in m.screens)
                  _ScreenRow(
                    screen: s,
                    flags: matrix[s.doctype] ?? const PermFlags(),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScreenRow extends ConsumerWidget {
  const _ScreenRow({required this.screen, required this.flags});
  final AdminScreenRef screen;
  final PermFlags flags;

  static const _types = [
    ('read', 'View'),
    ('create', 'Create'),
    ('write', 'Edit'),
    ('submit', 'Submit'),
    ('delete', 'Delete'),
    ('if_owner', 'Own only'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.md, AppDimens.xs, AppDimens.md, AppDimens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(screen.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(screen.doctype,
              style:
                  TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final t in _types)
                FilterChip(
                  label: Text(t.$2),
                  selected: flags.byType(t.$1),
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) async {
                    try {
                      await ref
                          .read(roleMatrixProvider.notifier)
                          .toggle(screen.doctype, t.$1, v);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
