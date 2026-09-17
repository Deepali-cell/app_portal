import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../expenses/application/expense_controller.dart';
import '../../expenses/domain/models.dart';
import '../../leave/application/leave_controller.dart';
import '../../leave/domain/models.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _dateShort = DateFormat('d MMM');

/// Requests waiting on the signed in user for approval, across Leave, Comp-Off
/// and Expense. Every tab is populated by the server: a row appears only when
/// the current user is the configured approver for that request (either the
/// first hop - manager / expense approver - or the HR hop). Nothing here is
/// role-gated in the app; the backend decides who sees what.
class ApprovalRequestsScreen extends StatelessWidget {
  const ApprovalRequestsScreen({super.key, this.initialTab = 0});

  /// 0 = Leave, 1 = Comp-Off, 2 = Expense. Lets the Leave and Expense screens
  /// deep-link straight to the relevant tab.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest,
          title: const Text('Approval Requests'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Leave'),
              Tab(text: 'Comp-Off'),
              Tab(text: 'Expense'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaveApprovalsTab(),
            _CompOffApprovalsTab(),
            _ExpenseApprovalsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leave tab
// ---------------------------------------------------------------------------
class _LeaveApprovalsTab extends ConsumerStatefulWidget {
  const _LeaveApprovalsTab();

  @override
  ConsumerState<_LeaveApprovalsTab> createState() => _LeaveApprovalsTabState();
}

class _LeaveApprovalsTabState extends ConsumerState<_LeaveApprovalsTab>
    with AutomaticKeepAliveClientMixin {
  String? _busyOn;

  @override
  bool get wantKeepAlive => true;

  Future<void> _act(PendingLeaveApproval item, String action) async {
    final reason = await _confirmOrReason(
      context,
      action: action,
      approveMessage:
          '${item.employeeName} has asked for ${_days(item.totalLeaveDays)} '
          'of ${item.leaveType}.',
      rejectWho: item.employeeName,
    );
    if (reason == _cancelled) return;

    setState(() => _busyOn = item.name);
    try {
      await ref.read(leaveControllerProvider.notifier).actOnApplication(
            name: item.name,
            action: action,
            reason: reason,
          );
      _toast(
          action == 'Approve'
              ? 'Approved. ${item.asHr ? "The request is now closed." : "Sent to HR."}'
              : 'Rejected.');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the request.');
    } finally {
      if (mounted) setState(() => _busyOn = null);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(pendingLeaveApprovalsProvider);
    return _ApprovalList<PendingLeaveApproval>(
      async: async,
      onRefresh: () => ref.invalidate(pendingLeaveApprovalsProvider),
      emptyText: 'No leave requests waiting on you.',
      cardBuilder: (item) => _ApprovalCard(
        title: item.employeeName,
        badge: item.asHr ? 'As HR' : 'Your team',
        line1: '${item.leaveType} · ${_days(item.totalLeaveDays)}'
            '${item.halfDay ? " · half day" : ""}',
        line2: _range(item.fromDate, item.toDate),
        stageLabel: item.stageLabel,
        note: item.description,
        busy: _busyOn == item.name,
        onApprove: () => _act(item, 'Approve'),
        onReject: () => _act(item, 'Reject'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comp-Off tab
// ---------------------------------------------------------------------------
class _CompOffApprovalsTab extends ConsumerStatefulWidget {
  const _CompOffApprovalsTab();

  @override
  ConsumerState<_CompOffApprovalsTab> createState() =>
      _CompOffApprovalsTabState();
}

class _CompOffApprovalsTabState extends ConsumerState<_CompOffApprovalsTab>
    with AutomaticKeepAliveClientMixin {
  String? _busyOn;

  @override
  bool get wantKeepAlive => true;

  Future<void> _act(PendingCompOffApproval item, String action) async {
    final reason = await _confirmOrReason(
      context,
      action: action,
      approveMessage: '${item.employeeName} worked on '
          '${_range(item.workFromDate, item.workEndDate)} and has asked for '
          'comp-off${item.halfDay ? " (half day)" : ""}.',
      rejectWho: item.employeeName,
    );
    if (reason == _cancelled) return;

    setState(() => _busyOn = item.name);
    try {
      await ref.read(leaveControllerProvider.notifier).actOnCompOff(
            name: item.name,
            action: action,
            reason: reason,
          );
      _toast(
          action == 'Approve'
              ? 'Approved. ${item.asHr ? "Comp-off days allocated." : "Sent to HR."}'
              : 'Rejected.');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the request.');
    } finally {
      if (mounted) setState(() => _busyOn = null);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(pendingCompOffApprovalsProvider);
    return _ApprovalList<PendingCompOffApproval>(
      async: async,
      onRefresh: () => ref.invalidate(pendingCompOffApprovalsProvider),
      emptyText: 'No comp-off requests waiting on you.',
      cardBuilder: (item) => _ApprovalCard(
        title: item.employeeName,
        badge: item.asHr ? 'As HR' : 'Your team',
        line1: 'Comp-Off · ${item.leaveType}'
            '${item.halfDay ? " · half day" : ""}',
        line2: 'Worked ${_range(item.workFromDate, item.workEndDate)}',
        stageLabel: item.stageLabel,
        note: item.reason,
        busy: _busyOn == item.name,
        onApprove: () => _act(item, 'Approve'),
        onReject: () => _act(item, 'Reject'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expense tab
// ---------------------------------------------------------------------------
class _ExpenseApprovalsTab extends ConsumerStatefulWidget {
  const _ExpenseApprovalsTab();

  @override
  ConsumerState<_ExpenseApprovalsTab> createState() =>
      _ExpenseApprovalsTabState();
}

class _ExpenseApprovalsTabState extends ConsumerState<_ExpenseApprovalsTab>
    with AutomaticKeepAliveClientMixin {
  String? _busyOn;

  @override
  bool get wantKeepAlive => true;

  Future<void> _act(PendingExpenseApproval item, String action) async {
    final money = NumberFormat.currency(name: '${item.currency} ', decimalDigits: 0);
    final reason = await _confirmOrReason(
      context,
      action: action,
      approveMessage: '${item.employeeName} has claimed '
          '${money.format(item.totalClaimed)}.',
      rejectWho: item.employeeName,
    );
    if (reason == _cancelled) return;

    setState(() => _busyOn = item.name);
    try {
      await ref.read(expenseControllerProvider.notifier).actOnClaim(
            name: item.name,
            action: action,
            reason: reason,
          );
      _toast(
          action == 'Approve'
              ? 'Approved. ${item.asHr ? "The claim is now closed." : "Sent to HR."}'
              : 'Rejected.');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not update the claim.');
    } finally {
      if (mounted) setState(() => _busyOn = null);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _viewItems(PendingExpenseApproval item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => _ClaimItemsSheet(name: item.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(pendingExpenseApprovalsProvider);
    return _ApprovalList<PendingExpenseApproval>(
      async: async,
      onRefresh: () => ref.invalidate(pendingExpenseApprovalsProvider),
      emptyText: 'No expense claims waiting on you.',
      cardBuilder: (item) {
        final money =
            NumberFormat.currency(name: '${item.currency} ', decimalDigits: 0);
        return _ApprovalCard(
          title: item.employeeName,
          badge: item.asHr ? 'As HR' : 'Your team',
          line1: 'Expense · ${money.format(item.totalClaimed)}',
          line2: _dateFmt.format(item.postingDate),
          stageLabel: item.stageLabel,
          note: item.remark,
          busy: _busyOn == item.name,
          onApprove: () => _act(item, 'Approve'),
          onReject: () => _act(item, 'Reject'),
          onViewDetail: () => _viewItems(item),
        );
      },
    );
  }
}

/// Bottom sheet listing an expense claim's line items, fetched on open.
class _ClaimItemsSheet extends ConsumerWidget {
  const _ClaimItemsSheet({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseClaimDetailProvider(name));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Text(e is ApiException ? e.message : 'Could not load items.'),
          ),
          data: (d) {
            final money =
                NumberFormat.currency(name: '${d.currency} ', decimalDigits: 0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${d.employeeName} · ${money.format(d.totalClaimed)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppDimens.md),
                ...d.lines.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.expenseType,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                                if (l.description != null &&
                                    l.description!.trim().isNotEmpty)
                                  Text(l.description!.trim(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color:
                                                  AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Text(money.format(l.amount),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                if (d.remark != null && d.remark!.trim().isNotEmpty) ...[
                  const Divider(height: AppDimens.xl),
                  Text(d.remark!.trim(),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared list + card + dialogs
// ---------------------------------------------------------------------------
class _ApprovalList<T> extends StatelessWidget {
  const _ApprovalList({
    required this.async,
    required this.onRefresh,
    required this.emptyText,
    required this.cardBuilder,
  });

  final AsyncValue<List<T>> async;
  final VoidCallback onRefresh;
  final String emptyText;
  final Widget Function(T item) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        onRefresh();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Text(
                e is ApiException ? e.message : 'Could not load the approvals.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimens.xxxl),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 40, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppDimens.md),
                      Text(emptyText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppDimens.screenPadding,
                AppDimens.md, AppDimens.screenPadding, AppDimens.xl),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppDimens.md),
            itemBuilder: (_, i) => cardBuilder(items[i]),
          );
        },
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.title,
    required this.badge,
    required this.line1,
    required this.line2,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    this.stageLabel,
    this.note,
    this.onViewDetail,
  });

  final String title;
  final String badge;
  final String line1;
  final String line2;
  final String? stageLabel;
  final String? note;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          color: AppColors.onSecondaryFixedVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(line1, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(line2, style: Theme.of(context).textTheme.labelLarge),
            if (stageLabel != null && stageLabel!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(stageLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant)),
            ],
            if (note != null && note!.trim().isNotEmpty) ...[
              const SizedBox(height: AppDimens.sm),
              Text(note!.trim(), style: Theme.of(context).textTheme.bodySmall),
            ],
            if (onViewDetail != null) ...[
              const SizedBox(height: AppDimens.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onViewDetail,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View items'),
                ),
              ),
            ],
            const SizedBox(height: AppDimens.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sentinel returned when the user backs out of the confirm/reason dialog, so
/// callers can tell "cancelled" apart from an empty (approve, no reason) result.
const String _cancelled = ' cancelled';

/// For Approve, shows a confirm dialog and returns null (no reason) or
/// [_cancelled]. For Reject, asks for a reason and returns it or [_cancelled].
Future<String?> _confirmOrReason(
  BuildContext context, {
  required String action,
  required String approveMessage,
  required String rejectWho,
}) async {
  if (action == 'Reject') {
    final r = await _askReason(context, rejectWho);
    return r ?? _cancelled;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Approve this request?'),
      content: Text(approveMessage),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve')),
      ],
    ),
  );
  return ok == true ? null : _cancelled;
}

Future<String?> _askReason(BuildContext context, String who) {
  final ctrl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Reject this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$who will see this reason.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'Required, at least 4 characters',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.length < 4) {
                setDialogState(() => error = 'At least 4 characters.');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    ),
  );
}

String _days(double d) =>
    d == d.truncate() ? '${d.toInt()} day${d == 1 ? "" : "s"}' : '$d days';

String _range(DateTime from, DateTime to) => from == to
    ? _dateFmt.format(from)
    : '${_dateShort.format(from)} to ${_dateFmt.format(to)}';
