import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../../projects/data/project_repository.dart';
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
