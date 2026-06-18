import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/brand_button.dart';
import '../application/providers.dart';
import '../domain/crm_ref.dart';
import '../domain/models.dart';

final _ts = DateFormat('d MMM, h:mm a');

const _callStatuses = [
  'Completed', 'No Answer', 'Busy', 'Failed', 'Canceled',
  'Initiated', 'Ringing', 'In Progress', 'Queued',
];

class CallsTab extends ConsumerWidget {
  const CallsTab({super.key, required this.crmRef, this.suggestedPhone});
  final CrmRef crmRef;
  final String? suggestedPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(callsProvider(crmRef));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.canvas,
        icon: const Icon(Icons.add_call),
        label: const Text('Log call'),
        onPressed: () => _openSheet(context, ref),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(e is ApiException ? e.message : 'Could not load calls.')),
        data: (calls) {
          if (calls.isEmpty) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(AppDimens.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.call_outlined,
                    size: 40, color: AppColors.inkFaint),
                const SizedBox(height: AppDimens.md),
                Text('No calls logged yet',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(callsProvider(crmRef)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding, AppDimens.screenPadding, AppDimens.screenPadding, 96),
              itemCount: calls.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppDimens.sm),
              itemBuilder: (_, i) => _CallCard(
                call: calls[i],
                onDial: () => _dial(context, calls[i].type == CallDirection.incoming
                    ? calls[i].fromNo : calls[i].to),
                onDelete: () => _delete(context, ref, calls[i].name),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _dial(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the dialer.')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete call log?'),
        content: const Text('This entry will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(crmCollabRepositoryProvider).deleteCall(name);
      ref.invalidate(callsProvider(crmRef));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) =>
          _CallSheet(crmRef: crmRef, suggestedPhone: suggestedPhone),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.call, required this.onDial, required this.onDelete});
  final CrmCall call;
  final VoidCallback onDial;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final isIn = call.type == CallDirection.incoming;
    final color = call.status == 'Completed'
        ? AppColors.success
        : (call.status == 'Failed' || call.status == 'No Answer'
            ? AppColors.danger
            : AppColors.warning);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.navyTint,
          child: Icon(
              isIn ? Icons.call_received : Icons.call_made,
              color: AppColors.navy, size: 18),
        ),
        title: Text(isIn ? call.fromNo : call.to,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${call.status} · ${call.startTime != null ? _ts.format(call.startTime!.toLocal()) : _ts.format(call.creation.toLocal())}'
          '${call.durationSeconds > 0 ? " · ${_dur(call.durationSeconds)}" : ""}',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Call back',
            icon: Icon(Icons.call, color: AppColors.navy),
            onPressed: onDial,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }

  String _dur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

class _CallSheet extends ConsumerStatefulWidget {
  const _CallSheet({required this.crmRef, this.suggestedPhone});
  final CrmRef crmRef;
  final String? suggestedPhone;
  @override
  ConsumerState<_CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends ConsumerState<_CallSheet> {
  late final _from = TextEditingController();
  late final _to = TextEditingController(text: widget.suggestedPhone ?? '');
  late final _duration = TextEditingController();
  String _type = 'Outgoing';
  String _status = 'Completed';
  DateTime _when = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _when,
        firstDate: DateTime(_when.year - 1),
        lastDate: DateTime(_when.year + 1));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_to.text.trim().isEmpty || _from.text.trim().isEmpty) {
      setState(() => _error = 'Both From and To numbers are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dur = int.tryParse(_duration.text.trim());
      await ref.read(crmCollabRepositoryProvider).createCall(
            widget.crmRef,
            fromNo: _from.text.trim(),
            to: _to.text.trim(),
            type: _type,
            status: _status,
            startTime: _when,
            durationSeconds: dur,
          );
      ref.invalidate(callsProvider(widget.crmRef));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Text('Log a call',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: const [
                    DropdownMenuItem(value: 'Outgoing', child: Text('Outgoing')),
                    DropdownMenuItem(value: 'Incoming', child: Text('Incoming')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _callStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ),
            ]),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _from,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'From number'),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _to,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'To number'),
            ),
            const SizedBox(height: AppDimens.lg),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickWhen,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'When',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(_ts.format(_when),
                        style: TextStyle(color: AppColors.ink)),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      const InputDecoration(labelText: 'Duration (s)'),
                ),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            BrandButton(
                label: 'Log call', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
