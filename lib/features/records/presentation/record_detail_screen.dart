import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../projects/data/project_repository.dart';
import '../../purchase/data/purchase_repository.dart';
import '../../purchase/presentation/purchase_comparison_screen.dart';
import '../../manufacturing/data/manufacturing_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/models.dart';
import '../data/records_repository.dart';
import '../domain/descriptor.dart';
import 'dynamic_form_screen.dart';

final _dateFmt = DateFormat('d MMM');

/// Generic detail view for an allowlisted doctype.
class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.args});
  final RecordArgs args;

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  Map<String, dynamic>? _doc;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await ref.read(recordsRepositoryProvider).getDoc(
            widget.args.descriptor.doctype,
            widget.args.name,
          );
      if (mounted) setState(() => _doc = doc);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.args.descriptor;
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final canEdit = profile?.canDo(d.cap, 'write') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(d.title),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => DynamicFormScreen(
                      doctype: d.doctype,
                      title: d.title,
                      name: widget.args.name,
                      initialValues: _doc ?? const {},
                    ),
                  ),
                );
                if (saved != null) _load();
              },
            ),
        ],
      ),
      body: _body(d),
    );
  }

  Widget _body(RecordDescriptor d) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Text('$_error', textAlign: TextAlign.center),
        ),
      );
    }
    final doc = _doc ?? const {};
    final header = _str(doc[d.titleField]).isNotEmpty
        ? _str(doc[d.titleField])
        : _str(doc['name']);
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        Text(header, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppDimens.xs),
        Text(_str(doc['name']),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppDimens.lg),
        for (final f in d.detailFields) _row(f, doc[f.key]),
        if (d.doctype == 'Project') ...[
          const SizedBox(height: AppDimens.lg),
          _ProjectTeamSection(project: widget.args.name),
          const SizedBox(height: AppDimens.lg),
          _ProjectTasksSection(project: widget.args.name),
        ],
        if (d.doctype == 'Material Request' &&
            _str(doc['material_request_type']) == 'Purchase' &&
            _str(doc['status']) != 'Draft' &&
            _str(doc['status']) != 'Cancelled') ...[
          const SizedBox(height: AppDimens.lg),
          _MaterialRequestRfqSection(materialRequest: widget.args.name),
        ],
        // ---- Purchase chain: next-step conversion buttons ----
        if (d.doctype == 'Request for Quotation' &&
            !{'Draft', 'Cancelled'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype, name: widget.args.name),
        ],
        if (d.doctype == 'Supplier Quotation' &&
            !{'Draft', 'Cancelled', 'Expired', 'Lost', 'Stopped'}
                .contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype, name: widget.args.name),
        ],
        if (d.doctype == 'Purchase Order' &&
            {'To Receive and Bill', 'To Receive'}
                .contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype, name: widget.args.name),
        ],
        if (d.doctype == 'Purchase Receipt' &&
            !{'Draft', 'Cancelled'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _PurchaseConversionSection(
              doctype: d.doctype, name: widget.args.name),
        ],
        if (d.doctype == 'Quotation' &&
            !{'Draft', 'Cancelled', 'Lost'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _SalesConversionSection(
            actions: [
              _SalesAction(
                label: 'Create Sales Order',
                targetKey: 'sales_order',
                run: (repo) => repo.createSoFromQuotation(widget.args.name),
              ),
            ],
          ),
        ],
        if (d.doctype == 'Sales Order' &&
            !{'Draft', 'Cancelled', 'Closed'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _SalesConversionSection(
            actions: [
              _SalesAction(
                label: 'Create Delivery Note',
                targetKey: 'sales_delivery',
                run: (repo) => repo.createDeliveryNoteFromSo(widget.args.name),
              ),
              _SalesAction(
                label: 'Create Invoice',
                targetKey: null,
                run: (repo) => repo.createInvoiceFromSo(widget.args.name),
              ),
            ],
          ),
        ],
        if (d.doctype == 'Delivery Note' &&
            !{'Draft', 'Cancelled'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _SalesConversionSection(
            actions: [
              _SalesAction(
                label: 'Create Invoice',
                targetKey: null,
                run: (repo) =>
                    repo.createInvoiceFromDeliveryNote(widget.args.name),
              ),
              _SalesAction(
                label: 'Create Return',
                targetKey: 'sales_delivery',
                run: (repo) => repo.createSalesReturn(widget.args.name),
              ),
            ],
          ),
        ],
        // ---- Manufacturing chain: next-step conversion buttons ----
        if (d.doctype == 'BOM' &&
            (doc['is_active'] == 1 || doc['is_active'] == true)) ...[
          const SizedBox(height: AppDimens.lg),
          _ManufacturingConversionSection(
            actions: [
              _ManufacturingAction(
                label: 'Create Work Order',
                targetKey: 'mfg_work_order',
                run: (repo) => repo.createWorkOrderFromBom(widget.args.name),
              ),
            ],
          ),
        ],
        if (d.doctype == 'Work Order' &&
            {'Not Started', 'In Process'}.contains(_str(doc['status']))) ...[
          const SizedBox(height: AppDimens.lg),
          _ManufacturingConversionSection(
            actions: [
              _ManufacturingAction(
                label: 'Transfer Material',
                targetKey: 'stock_entry',
                run: (repo) => repo.createStockEntryFromWorkOrder(
                  widget.args.name,
                  purpose: 'Material Transfer for Manufacture',
                ),
              ),
              _ManufacturingAction(
                label: 'Manufacture',
                targetKey: 'stock_entry',
                run: (repo) => repo.createStockEntryFromWorkOrder(
                  widget.args.name,
                  purpose: 'Manufacture',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _row(FieldSpec f, dynamic value) {
    final text = f.isBool
        ? ((value == 1 || value == true) ? 'Yes' : 'No')
        : _str(value);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(f.label,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _str(dynamic v) => v == null ? '' : v.toString();
}

/// Project team ("Assign Projects"): who this project is assigned to, with
/// add/remove. Separate from the generic edit form because `users` is a
/// child table Frappe's list query can't select (see project_repository.dart).
class _ProjectTeamSection extends ConsumerStatefulWidget {
  const _ProjectTeamSection({required this.project});
  final String project;

  @override
  ConsumerState<_ProjectTeamSection> createState() => _ProjectTeamSectionState();
}

class _ProjectTeamSectionState extends ConsumerState<_ProjectTeamSection> {
  List<ProjectMember>? _team;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final team =
          await ref.read(projectRepositoryProvider).getTeam(widget.project);
      if (mounted) {
        setState(() {
          _team = team;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _addMember() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked == null) return;
    try {
      await ref.read(projectRepositoryProvider).addMember(widget.project, picked);
      _load();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _removeMember(String user) async {
    try {
      await ref.read(projectRepositoryProvider).removeMember(widget.project, user);
      _load();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Team',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Assign'),
                ),
              ],
            ),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_team == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_team ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('Nobody assigned yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final m in _team!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.onPrimaryContainer),
                    ),
                  ),
                  title: Text(m.fullName),
                  subtitle: Text(m.user),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeMember(m.user),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Project tasks: every Task under this project, any status/assignee, with
/// quick create/status-change/assign. Reuses the bespoke Task feature's
/// repository - Task keeps its own richer screen for "my tasks" elsewhere.
class _ProjectTasksSection extends ConsumerStatefulWidget {
  const _ProjectTasksSection({required this.project});
  final String project;

  @override
  ConsumerState<_ProjectTasksSection> createState() => _ProjectTasksSectionState();
}

class _ProjectTasksSectionState extends ConsumerState<_ProjectTasksSection> {
  List<TaskItem>? _tasks;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await ref
          .read(taskRepositoryProvider)
          .listByProject(widget.project);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _addTask() async {
    final subject = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewTaskSubjectSheet(),
    );
    if (subject == null || subject.trim().isEmpty) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          .create(subject: subject.trim(), project: widget.project);
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _changeStatus(TaskItem task) async {
    const statuses = ['Open', 'Working', 'Pending Review', 'Completed', 'Cancelled'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Set status', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in statuses)
              ListTile(
                title: Text(s),
                trailing: s == task.status ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != task.status) {
      try {
        await ref.read(taskRepositoryProvider).setStatus(task.name, picked);
        _load();
      } on ApiException catch (e) {
        if (mounted) _snack(e.message);
      }
    }
  }

  Future<void> _assign(TaskItem task) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UserSearchSheet(),
    );
    if (picked == null) return;
    try {
      await ref.read(taskRepositoryProvider).assign(task.name, picked);
      _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tasks',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add task'),
                ),
              ],
            ),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_tasks == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_tasks ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('No tasks under this project yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final t in _tasks!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.subject),
                  subtitle: Text(
                    [
                      t.status,
                      t.priority,
                      if (t.expEndDate != null) 'Due ${_dateFmt.format(t.expEndDate!)}',
                      if (t.assignees.isNotEmpty) 'Assigned: ${t.assignees.join(', ')}',
                    ].join('  •  '),
                  ),
                  onTap: () => _changeStatus(t),
                  trailing: IconButton(
                    tooltip: 'Assign',
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () => _assign(t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Minimal "subject only" sheet for quickly adding a task under a project.
class _NewTaskSubjectSheet extends StatefulWidget {
  const _NewTaskSubjectSheet();
  @override
  State<_NewTaskSubjectSheet> createState() => _NewTaskSubjectSheetState();
}

class _NewTaskSubjectSheetState extends State<_NewTaskSubjectSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppDimens.xl, AppDimens.xl, AppDimens.xl,
          AppDimens.xl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Subject'),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: AppDimens.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Material Request -> RFQ conversion. Lists RFQs already raised against this
/// MR and lets the user raise a new one by picking suppliers to invite -
/// ERPNext's own make_request_for_quotation() maps over the pending items.
class _MaterialRequestRfqSection extends ConsumerStatefulWidget {
  const _MaterialRequestRfqSection({required this.materialRequest});
  final String materialRequest;

  @override
  ConsumerState<_MaterialRequestRfqSection> createState() =>
      _MaterialRequestRfqSectionState();
}

class _MaterialRequestRfqSectionState
    extends ConsumerState<_MaterialRequestRfqSection> {
  List<Map<String, dynamic>>? _rfqs;
  Object? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rfqs = await ref
          .read(purchaseRepositoryProvider)
          .rfqsForMaterialRequest(widget.materialRequest);
      if (mounted) {
        setState(() {
          _rfqs = rfqs;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _createRfq() async {
    final suppliers = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SupplierMultiSelectSheet(),
    );
    if (suppliers == null || suppliers.isEmpty) return;

    setState(() => _creating = true);
    try {
      final name = await ref
          .read(purchaseRepositoryProvider)
          .createRfqFromMaterialRequest(widget.materialRequest, suppliers);
      if (!mounted) return;
      _snack('RFQ created: $name');
      _load();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(
            args: RecordArgs(recordRegistry['purchase_rfq']!, name),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('RFQs',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _creating ? null : _createRfq,
                  icon: _creating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Create RFQ'),
                ),
              ],
            ),
            if (_error != null)
              Text('$_error', style: const TextStyle(color: AppColors.error)),
            if (_rfqs == null && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else if ((_rfqs ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
                child: Text('No RFQ raised yet',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              )
            else
              for (final r in _rfqs!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r['name']?.toString() ?? ''),
                  subtitle: Text(r['status']?.toString() ?? ''),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordDetailScreen(
                        args: RecordArgs(
                          recordRegistry['purchase_rfq']!,
                          r['name'].toString(),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Purchase-chain "Next step" buttons shown on RFQ / Supplier Quotation /
/// Purchase Order / Purchase Receipt detail screens. Mirrors the Sales
/// conversion pattern; the RFQ and Return steps need a small picker first,
/// the rest are one tap. Backed by tcb_portal_erp.api.purchase.
class _PurchaseConversionSection extends ConsumerStatefulWidget {
  const _PurchaseConversionSection({required this.doctype, required this.name});
  final String doctype;
  final String name;

  @override
  ConsumerState<_PurchaseConversionSection> createState() =>
      _PurchaseConversionSectionState();
}

class _PurchaseConversionSectionState
    extends ConsumerState<_PurchaseConversionSection> {
  bool _running = false;

  PurchaseRepository get _repo => ref.read(purchaseRepositoryProvider);

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _oneTap(
    Future<String> Function() run,
    String label, {
    String? targetKey,
  }) async {
    setState(() => _running = true);
    try {
      final name = await run();
      if (!mounted) return;
      _snack('$label: $name');
      if (targetKey != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              args: RecordArgs(recordRegistry[targetKey]!, name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _createSqFromRfq() async {
    List<Map<String, dynamic>> suppliers;
    try {
      suppliers = await _repo.rfqSuppliers(widget.name);
    } catch (e) {
      if (mounted) _snack('Failed: $e');
      return;
    }
    if (!mounted) return;
    if (suppliers.isEmpty) {
      _snack('No suppliers invited on this RFQ');
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Create quotation for supplier',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in suppliers)
              ListTile(
                title: Text((s['supplier_name'] ?? s['supplier']).toString()),
                subtitle: Text((s['supplier'] ?? '').toString()),
                onTap: () =>
                    Navigator.pop(context, (s['supplier'] ?? '').toString()),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    await _oneTap(
      () => _repo.createSupplierQuotationFromRfq(widget.name, picked),
      'Supplier Quotation',
      targetKey: 'purchase_supplier_quotation',
    );
  }

  Future<void> _createReturn() async {
    List<Map<String, dynamic>> items;
    try {
      items = await _repo.receiptItems(widget.name);
    } catch (e) {
      if (mounted) _snack('Failed: $e');
      return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReturnItemsSheet(items: items),
    );
    if (result == null || result.isEmpty) return;
    await _oneTap(
      () => _repo.createPurchaseReturn(widget.name, result),
      'Return',
      targetKey: 'purchase_receipt',
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinner = _running;
    Widget primaryBtn(String label, IconData icon, VoidCallback onTap) =>
        FilledButton.icon(
          onPressed: spinner ? null : onTap,
          icon: spinner
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(icon, size: 18),
          label: Text(label),
        );
    Widget outlineBtn(String label, IconData icon, VoidCallback onTap) =>
        OutlinedButton.icon(
          onPressed: spinner ? null : onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        );

    final buttons = <Widget>[];
    switch (widget.doctype) {
      case 'Request for Quotation':
        buttons.add(primaryBtn('Create Supplier Quotation',
            Icons.request_quote_outlined, _createSqFromRfq));
        buttons.add(outlineBtn(
            'Compare Quotations',
            Icons.compare_arrows,
            () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PurchaseComparisonScreen(
                      requestForQuotation: widget.name),
                ))));
        break;
      case 'Supplier Quotation':
        buttons.add(primaryBtn(
            'Create Purchase Order',
            Icons.shopping_cart_outlined,
            () => _oneTap(
                () => _repo.createPoFromSupplierQuotation(widget.name),
                'Purchase Order',
                targetKey: 'purchase_order')));
        break;
      case 'Purchase Order':
        buttons.add(primaryBtn(
            'Create Receipt (GRN)',
            Icons.inventory_2_outlined,
            () => _oneTap(() => _repo.createReceiptFromPo(widget.name),
                'Purchase Receipt',
                targetKey: 'purchase_receipt')));
        break;
      case 'Purchase Receipt':
        buttons.add(primaryBtn(
            'Create Invoice',
            Icons.receipt_long_outlined,
            () => _oneTap(() => _repo.createInvoiceFromReceipt(widget.name),
                'Purchase Invoice')));
        buttons.add(outlineBtn('Create Return',
            Icons.assignment_return_outlined, _createReturn));
        break;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next step',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.sm,
              children: buttons,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quantity sheet for a Purchase Return: lists the receipt's items with their
/// returnable qty (received - already returned) and lets the user enter how
/// much of each to return. Returns [{item_code, qty}] for the picked rows.
class _ReturnItemsSheet extends StatefulWidget {
  const _ReturnItemsSheet({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<_ReturnItemsSheet> createState() => _ReturnItemsSheetState();
}

class _ReturnItemsSheetState extends State<_ReturnItemsSheet> {
  late final Map<String, TextEditingController> _controllers;

  double _returnable(Map<String, dynamic> it) {
    final rec = (it['received_qty'] as num?)?.toDouble() ?? 0;
    final ret = (it['returned_qty'] as num?)?.toDouble() ?? 0;
    final left = rec - ret;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final it in widget.items)
        (it['item_code'] ?? '').toString(): TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <Map<String, dynamic>>[];
    for (final it in widget.items) {
      final code = (it['item_code'] ?? '').toString();
      final qty = double.tryParse(_controllers[code]?.text.trim() ?? '') ?? 0;
      if (qty > 0) out.add({'item_code': code, 'qty': qty});
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimens.lg),
              child: Text('Return quantities',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = widget.items[i];
                  final code = (it['item_code'] ?? '').toString();
                  final name = (it['item_name'] ?? code).toString();
                  final left = _returnable(it);
                  return ListTile(
                    title: Text(name),
                    subtitle: Text('$code  •  returnable: $left'),
                    trailing: SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _controllers[code],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          isDense: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Create Return'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select Supplier picker for inviting suppliers on a new RFQ.
class _SupplierMultiSelectSheet extends ConsumerStatefulWidget {
  const _SupplierMultiSelectSheet();
  @override
  ConsumerState<_SupplierMultiSelectSheet> createState() =>
      _SupplierMultiSelectSheetState();
}

class _SupplierMultiSelectSheetState
    extends ConsumerState<_SupplierMultiSelectSheet> {
  List<Map<String, String>> _results = const [];
  final Set<String> _selected = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(recordsRepositoryProvider)
          .searchLink('Supplier', txt: txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search suppliers…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  final value = r['value'] ?? '';
                  return CheckboxListTile(
                    value: _selected.contains(value),
                    title: Text(r['label'] ?? ''),
                    subtitle:
                        (r['label'] != value) ? Text(value) : null,
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(value);
                      } else {
                        _selected.remove(value);
                      }
                    }),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.md),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                  child: Text('Invite ${_selected.length} supplier(s)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable User picker, reused for "assign project" and "assign task".
class _UserSearchSheet extends ConsumerStatefulWidget {
  const _UserSearchSheet();
  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  List<Map<String, String>> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r =
          await ref.read(recordsRepositoryProvider).searchLink('User', txt: txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search user…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    title: Text(r['label'] ?? ''),
                    subtitle: (r['label'] != r['value']) ? Text(r['value'] ?? '') : null,
                    onTap: () => Navigator.of(context).pop(r['value']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One document-conversion action (e.g. "Create Delivery Note" from a Sales
/// Order). `targetKey` is the recordRegistry key to open on success, or null
/// when the created doc has no generic record screen (e.g. Sales Invoice,
/// which uses the bespoke invoices/ feature instead).
class _SalesAction {
  const _SalesAction({
    required this.label,
    required this.targetKey,
    required this.run,
  });
  final String label;
  final String? targetKey;
  final Future<String> Function(SalesRepository repo) run;
}

/// Sales-cycle conversion buttons shown on Quotation/Sales Order/Delivery
/// Note detail screens. Mirrors the Purchase module's conversion-action
/// pattern (_MaterialRequestRfqSection) but as simple one-tap buttons since
/// each of these steps creates exactly one draft document, not a list.
class _SalesConversionSection extends ConsumerStatefulWidget {
  const _SalesConversionSection({required this.actions});
  final List<_SalesAction> actions;

  @override
  ConsumerState<_SalesConversionSection> createState() =>
      _SalesConversionSectionState();
}

class _SalesConversionSectionState
    extends ConsumerState<_SalesConversionSection> {
  bool _running = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(_SalesAction action) async {
    setState(() => _running = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final name = await action.run(repo);
      if (!mounted) return;
      _snack('${action.label}: $name');
      final targetKey = action.targetKey;
      if (targetKey != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              args: RecordArgs(recordRegistry[targetKey]!, name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Wrap(
          spacing: AppDimens.sm,
          runSpacing: AppDimens.sm,
          children: [
            for (final action in widget.actions)
              FilledButton.icon(
                onPressed: _running ? null : () => _run(action),
                icon: _running
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}

/// One next-step action on the Manufacturing detail (e.g. BOM -> Work Order).
/// `targetKey` is the recordRegistry key to open on success.
class _ManufacturingAction {
  const _ManufacturingAction({
    required this.label,
    required this.targetKey,
    required this.run,
  });
  final String label;
  final String? targetKey;
  final Future<String> Function(ManufacturingRepository repo) run;
}

/// Manufacturing-cycle conversion buttons shown on BOM/Work Order detail
/// screens. Mirrors the Sales/Purchase conversion-action pattern: each tap
/// creates exactly one draft document and opens it.
class _ManufacturingConversionSection extends ConsumerStatefulWidget {
  const _ManufacturingConversionSection({required this.actions});
  final List<_ManufacturingAction> actions;

  @override
  ConsumerState<_ManufacturingConversionSection> createState() =>
      _ManufacturingConversionSectionState();
}

class _ManufacturingConversionSectionState
    extends ConsumerState<_ManufacturingConversionSection> {
  bool _running = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(_ManufacturingAction action) async {
    setState(() => _running = true);
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final name = await action.run(repo);
      if (!mounted) return;
      _snack('${action.label}: $name');
      final targetKey = action.targetKey;
      if (targetKey != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              args: RecordArgs(recordRegistry[targetKey]!, name),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.md),
        child: Wrap(
          spacing: AppDimens.sm,
          runSpacing: AppDimens.sm,
          children: [
            for (final action in widget.actions)
              FilledButton.icon(
                onPressed: _running ? null : () => _run(action),
                icon: _running
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
