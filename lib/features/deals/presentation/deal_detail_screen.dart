import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../call_outcome/presentation/call_outcome_sheet.dart';
import '../../crm_shared/domain/crm_ref.dart';
import 'probability_pill.dart';
import '../../crm_shared/presentation/activity_tab.dart';
import '../../crm_shared/presentation/assignees_tab.dart';
import '../../crm_shared/presentation/attachments_tab.dart';
import '../../crm_shared/presentation/calls_tab.dart';
import '../../crm_shared/presentation/comments_tab.dart';
import '../../crm_shared/presentation/emails_tab.dart';
import '../../crm_shared/presentation/events_tab.dart';
import '../../crm_shared/presentation/notes_tab.dart';
import '../../crm_shared/presentation/tasks_tab.dart';
import '../application/deal_controller.dart';
import '../domain/models.dart';

class DealDetailScreen extends ConsumerStatefulWidget {
  const DealDetailScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends ConsumerState<DealDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 10, vsync: this)
    ..addListener(() => setState(() {}));

  bool _editing = false;
  bool _saving = false;

  final Map<String, TextEditingController> _ctrls = {
    for (final f in [
      'salutation','first_name','last_name','gender',
      'email','mobile_no','phone','website',
      'organization','organization_name','job_title','no_of_employees','industry','source','territory','deal_owner',
      'deal_value','probability','annual_revenue','next_step',
    ]) f: TextEditingController()
  };
  String? _status;

  CrmRef get _ref => CrmRef(doctype: 'CRM Deal', name: widget.name);

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _prime(Deal d) {
    _ctrls['salutation']!.text = d.salutation ?? '';
    _ctrls['first_name']!.text = d.firstName ?? '';
    _ctrls['last_name']!.text = d.lastName ?? '';
    _ctrls['gender']!.text = d.gender ?? '';
    _ctrls['email']!.text = d.email ?? '';
    _ctrls['mobile_no']!.text = d.mobileNo ?? '';
    _ctrls['phone']!.text = d.phone ?? '';
    _ctrls['website']!.text = d.website ?? '';
    _ctrls['organization']!.text = d.organization ?? '';
    _ctrls['organization_name']!.text = d.organizationName ?? '';
    _ctrls['job_title']!.text = d.jobTitle ?? '';
    _ctrls['no_of_employees']!.text = d.noOfEmployees ?? '';
    _ctrls['industry']!.text = d.industry ?? '';
    _ctrls['source']!.text = d.source ?? '';
    _ctrls['territory']!.text = d.territory ?? '';
    _ctrls['deal_owner']!.text = d.dealOwner ?? '';
    _ctrls['deal_value']!.text = d.dealValue == 0 ? '' : d.dealValue.toString();
    _ctrls['annual_revenue']!.text = d.annualRevenue == 0 ? '' : d.annualRevenue.toString();
    _ctrls['probability']!.text = d.probability == null ? '' : d.probability!.toString();
    _ctrls['next_step']!.text = d.nextStep ?? '';
    _status = d.status;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final fields = <String, dynamic>{
      for (final e in _ctrls.entries)
        e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      if (_status != null) 'status': _status,
    };
    fields['deal_value'] = double.tryParse((fields['deal_value'] ?? '').toString());
    fields['annual_revenue'] = double.tryParse((fields['annual_revenue'] ?? '').toString());
    fields['probability'] = double.tryParse((fields['probability'] ?? '').toString());
    try {
      await ref.read(dealsControllerProvider.notifier).save(widget.name, fields);
      if (mounted) setState(() => _editing = false);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dealDetailProvider(widget.name));
    final statuses =
        ref.watch(dealsControllerProvider).value?.statuses ?? const <String>[];
    final onDetailsTab = _tabs.index == 0;
    final deal = async.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(deal?.title ?? 'Deal'),
        actions: [
          if (onDetailsTab && deal != null && !_editing)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                _prime(deal);
                setState(() => _editing = true);
              },
            ),
          if (onDetailsTab && _editing) ...[
            TextButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.navy,
          tabs: [
            const Tab(text: 'Details'),
            Tab(text: 'Comments${_count(deal?.counts.comments)}'),
            Tab(text: 'Notes${_count(deal?.counts.notes)}'),
            Tab(text: 'Attachments${_count(deal?.counts.attachments)}'),
            Tab(text: 'Email${_count(deal?.counts.emails)}'),
            Tab(text: 'Assign to${_count(deal?.assignees.length)}'),
            const Tab(text: 'Activity'),
            Tab(text: 'Tasks${_count(deal?.counts.tasks)}'),
            Tab(text: 'Calls${_count(deal?.counts.calls)}'),
            Tab(text: 'Events${_count(deal?.counts.events)}'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(context, e),
        data: (deal) => TabBarView(
          controller: _tabs,
          children: [
            _DetailsTab(deal: deal, editing: _editing, ctrls: _ctrls, statuses: statuses, status: _status, onStatus: (s) => setState(() => _status = s)),
            CommentsTab(crmRef: _ref),
            NotesTab(crmRef: _ref),
            AttachmentsTab(crmRef: _ref),
            EmailsTab(crmRef: _ref, suggestedTo: deal.email),
            AssigneesTab(crmRef: _ref),
            ActivityTab(crmRef: _ref),
            CrmTasksTab(crmRef: _ref),
            CallsTab(crmRef: _ref, suggestedPhone: deal.mobileNo ?? deal.phone),
            EventsTab(crmRef: _ref),
          ],
        ),
      ),
    );
  }

  String _count(int? n) => (n == null || n == 0) ? '' : '  $n';

  Widget _err(BuildContext context, Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: AppDimens.md),
            Text(e is ApiException ? e.message : 'Could not load.',
                textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            OutlinedButton(
              onPressed: () => ref.invalidate(dealDetailProvider(widget.name)),
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.deal,
    required this.editing,
    required this.ctrls,
    required this.statuses,
    required this.status,
    required this.onStatus,
  });

  final Deal deal;
  final bool editing;
  final Map<String, TextEditingController> ctrls;
  final List<String> statuses;
  final String? status;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        _DealHeader(deal: deal),
        const SizedBox(height: AppDimens.lg),
        _QuickContact(deal: deal),
        const SizedBox(height: AppDimens.xl),
        _Section(title: 'Deal', children: [
          if (editing) _statusEditor(context)
          else _row('Status', deal.status, null, editing: false),
          _row('Deal value', editing ? null : (deal.dealValue == 0 ? null : money(deal.dealValue, deal.currency)),
              ctrls['deal_value'], editing: editing, keyboardType: const TextInputType.numberWithOptions(decimal: true), numberOnly: true),
          if (editing)
            _row('Probability %', null, ctrls['probability'],
                editing: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                numberOnly: true)
          else
            _ProbabilityRow(probability: deal.probability),
          _row('Annual revenue', editing ? null : (deal.annualRevenue == 0 ? null : money(deal.annualRevenue, deal.currency)),
              ctrls['annual_revenue'], editing: editing, keyboardType: const TextInputType.numberWithOptions(decimal: true), numberOnly: true),
          _row('Next step', deal.nextStep, ctrls['next_step'], editing: editing),
          _row('Owner', deal.dealOwner, ctrls['deal_owner'], editing: editing),
          _row('Source', deal.source, ctrls['source'], editing: editing),
          _row('Territory', deal.territory, ctrls['territory'], editing: editing),
        ]),
        _Section(title: 'Contact', children: [
          _row('Salutation', deal.salutation, ctrls['salutation'], editing: editing),
          _row('First name', deal.firstName, ctrls['first_name'], editing: editing),
          _row('Last name', deal.lastName, ctrls['last_name'], editing: editing),
          _row('Gender', deal.gender, ctrls['gender'], editing: editing),
          _row('Email', deal.email, ctrls['email'], editing: editing, keyboardType: TextInputType.emailAddress),
          _row('Mobile', deal.mobileNo, ctrls['mobile_no'], editing: editing, keyboardType: TextInputType.phone),
          _row('Phone', deal.phone, ctrls['phone'], editing: editing, keyboardType: TextInputType.phone),
          _row('Website', deal.website, ctrls['website'], editing: editing, keyboardType: TextInputType.url),
        ]),
        _Section(title: 'Organization', children: [
          _row('Organization', deal.organization, ctrls['organization'], editing: editing),
          _row('Display name', deal.organizationName, ctrls['organization_name'], editing: editing),
          _row('Job title', deal.jobTitle, ctrls['job_title'], editing: editing),
          _row('Employees', deal.noOfEmployees, ctrls['no_of_employees'], editing: editing),
          _row('Industry', deal.industry, ctrls['industry'], editing: editing),
        ]),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _statusEditor(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: DropdownButtonFormField<String>(
          initialValue: statuses.contains(status) ? status : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status'),
          items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onStatus,
        ),
      );

  Widget _row(String label, String? value, TextEditingController? c,
      {required bool editing, TextInputType? keyboardType, bool numberOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: editing && c != null
          ? TextField(
              controller: c,
              keyboardType: keyboardType,
              inputFormatters: numberOnly
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                  : null,
              decoration: InputDecoration(labelText: label),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label,
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                ),
                Expanded(
                  child: Text(
                    (value == null || value.isEmpty) ? '-' : value,
                    style: TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppDimens.lg, AppDimens.md, AppDimens.lg, AppDimens.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: TextStyle(
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.6)),
                const SizedBox(height: AppDimens.sm),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _DealHeader extends StatelessWidget {
  const _DealHeader({required this.deal});
  final Deal deal;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.navy,
          child: Text((deal.title.isNotEmpty ? deal.title[0] : '?').toUpperCase(),
              style: TextStyle(
                  color: AppColors.canvas, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deal.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (deal.dealValue > 0)
                Text(money(deal.dealValue, deal.currency),
                    style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppDimens.xs),
              Wrap(spacing: AppDimens.xs, runSpacing: AppDimens.xs, children: [
                _chip(deal.status, AppColors.navy, filled: true),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color c, {bool filled = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? c.withValues(alpha: 0.12) : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({required this.deal});
  final Deal deal;

  Future<void> _launch(Uri uri, BuildContext context) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app available to handle this.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_Quick>[];
    if (deal.mobileNo != null && deal.mobileNo!.isNotEmpty) {
      actions.add(_Quick(Icons.phone, 'Call', () => _launch(Uri(scheme: 'tel', path: deal.mobileNo!), context)));
    }
    if (deal.phone != null && deal.phone!.isNotEmpty && deal.phone != deal.mobileNo) {
      actions.add(_Quick(Icons.call_outlined, 'Phone', () => _launch(Uri(scheme: 'tel', path: deal.phone!), context)));
    }
    if (deal.email != null && deal.email!.isNotEmpty) {
      actions.add(_Quick(Icons.mail_outline, 'Email', () => _launch(Uri(scheme: 'mailto', path: deal.email!), context)));
    }
    if (deal.website != null && deal.website!.isNotEmpty) {
      actions.add(_Quick(Icons.public, 'Web', () => _launch(Uri.parse(_norm(deal.website!)), context)));
    }
    actions.add(_Quick(Icons.phone_callback, 'Log call', () async {
      final newId = await showCallOutcomeSheet(
        context,
        referenceDoctype: 'CRM Deal',
        referenceDocname: deal.name,
        parentLabel: deal.title,
      );
      if (newId != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call outcome saved.')));
      }
    }));
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(children: actions.map((a) => Expanded(child: _QuickButton(action: a))).toList());
  }

  String _norm(String u) => (u.startsWith('http://') || u.startsWith('https://')) ? u : 'https://$u';
}

class _Quick {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.action});
  final _Quick action;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        onPressed: action.onTap,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
        ),
      ),
    );
  }
}

/// Read-only probability row that renders the colour-coded [ProbabilityPill]
/// instead of plain text. Used in the Deal detail screen when NOT editing.
class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({required this.probability});
  final double? probability;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text('Probability',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ),
          ProbabilityPill(percent: probability, dense: false),
        ],
      ),
    );
  }
}
