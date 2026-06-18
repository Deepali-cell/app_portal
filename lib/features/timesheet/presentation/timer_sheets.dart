import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../application/timesheet_controller.dart';
import '../domain/models.dart';

/// Modal sheet — pick activity → project → task → Start.
class StartTimerSheet extends ConsumerStatefulWidget {
  const StartTimerSheet({super.key, required this.ctx});
  final TimesheetContext ctx;
  @override
  ConsumerState<StartTimerSheet> createState() => _StartTimerSheetState();
}

class _StartTimerSheetState extends ConsumerState<StartTimerSheet> {
  String? _activity;
  String? _project;
  String? _task;
  bool _busy = false;
  String? _error;

  bool get _ready => _activity != null && _project != null && _task != null;

  Future<void> _start() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(timesheetControllerProvider.notifier).startTimer(
            activityType: _activity!,
            project: _project!,
            task: _task!,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start the timer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tasksAsync = _project == null
        ? const AsyncValue<List<TaskRef>>.data([])
        : ref.watch(projectTasksProvider(_project!));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Text('Start Timer',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.xl),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activity'),
              items: widget.ctx.activityTypes
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _project,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project'),
              items: widget.ctx.projects
                  .map((p) =>
                      DropdownMenuItem(value: p.name, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => setState(() {
                _project = v;
                _task = null;
              }),
            ),
            const SizedBox(height: AppDimens.lg),
            tasksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.md),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                  e is ApiException ? e.message : 'Could not load tasks.',
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13)),
              data: (tasks) {
                if (_project == null) {
                  return Text('Pick a project first.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                if (tasks.isEmpty) {
                  return Text('No open tasks on this project.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                return DropdownButtonFormField<String>(
                  initialValue:
                      tasks.any((t) => t.name == _task) ? _task : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Task'),
                  items: tasks
                      .map((t) => DropdownMenuItem(
                          value: t.name, child: Text(t.subject)))
                      .toList(),
                  onChanged: (v) => setState(() => _task = v),
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            FilledButton.icon(
              onPressed: (_ready && !_busy) ? _start : null,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal sheet — enter description (mandatory, ≥ 4 chars) → Stop.
class StopTimerSheet extends ConsumerStatefulWidget {
  const StopTimerSheet({super.key, required this.timer});
  final ActiveTimer timer;
  @override
  ConsumerState<StopTimerSheet> createState() => _StopTimerSheetState();
}

class _StopTimerSheetState extends ConsumerState<StopTimerSheet> {
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _stop() async {
    final desc = _description.text.trim();
    if (desc.length < 4) {
      setState(() =>
          _error = 'Description is required (at least 4 characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(timesheetControllerProvider.notifier).stopTimer(desc);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not stop the timer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _elapsed() {
    final d = widget.timer.elapsedNow();
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
                child: Text('Stop Timer',
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: AppDimens.md),
            Container(
              padding: const EdgeInsets.all(AppDimens.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.timer.task,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      '${widget.timer.activityType} · ${widget.timer.project}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Elapsed: ${_elapsed()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What did you work on?',
                alignLabelWithHint: true,
                hintText: 'Required — at least 4 characters',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                  child: const Text('Keep Running'),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _stop,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showStopTimerSheet(BuildContext context, ActiveTimer timer) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => StopTimerSheet(timer: timer),
    );

Future<bool?> showStartTimerSheet(BuildContext context, TimesheetContext ctx) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => StartTimerSheet(ctx: ctx),
    );

/// Modal sheet — back-fill time for users who forgot to start the timer.
///
/// Collects activity / project / task / start datetime / hours / description
/// and posts them in one go via the `create` endpoint. Hours must be > 0.
class LogPastTimeSheet extends ConsumerStatefulWidget {
  const LogPastTimeSheet({super.key, required this.ctx});
  final TimesheetContext ctx;

  @override
  ConsumerState<LogPastTimeSheet> createState() => _LogPastTimeSheetState();
}

class _LogPastTimeSheetState extends ConsumerState<LogPastTimeSheet> {
  String? _activity;
  String? _project;
  String? _task;
  DateTime _start = DateTime.now().subtract(const Duration(hours: 1));
  final _hoursCtrl = TextEditingController(text: '1.0');
  final _descCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  static final _dateFmt = DateFormat('d MMM yyyy · h:mm a');

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (pickedTime == null) return;
    setState(() {
      _start = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    final hours = double.tryParse(_hoursCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    if (_activity == null) {
      setState(() => _error = 'Pick an activity type.');
      return;
    }
    if (_project == null || _task == null) {
      setState(() => _error = 'Pick a project and a task.');
      return;
    }
    if (hours == null || hours <= 0) {
      setState(() => _error = 'Hours must be greater than zero.');
      return;
    }
    if (_start.isAfter(DateTime.now())) {
      setState(() => _error = 'Start time cannot be in the future.');
      return;
    }
    if (desc.length < 4) {
      setState(() => _error = 'Add a short description (≥ 4 chars).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(timesheetControllerProvider.notifier).create([
        TimeLog(
          fromTime: _start,
          hours: hours,
          activityType: _activity,
          project: _project,
          task: _task,
          description: desc,
        ),
      ]);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the entry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tasksAsync = _project == null
        ? const AsyncValue<List<TaskRef>>.data([])
        : ref.watch(projectTasksProvider(_project!));
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.xl, AppDimens.xl, AppDimens.xl, AppDimens.xl + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Log Past Time',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: AppDimens.xs),
            Center(
              child: Text(
                'For work you did but forgot to start a timer for.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppDimens.xl),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Activity'),
              items: widget.ctx.activityTypes
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v),
            ),
            const SizedBox(height: AppDimens.lg),
            DropdownButtonFormField<String>(
              initialValue: _project,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project'),
              items: widget.ctx.projects
                  .map((p) =>
                      DropdownMenuItem(value: p.name, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => setState(() {
                _project = v;
                _task = null;
              }),
            ),
            const SizedBox(height: AppDimens.lg),
            tasksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.md),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                  e is ApiException ? e.message : 'Could not load tasks.',
                  style: TextStyle(color: AppColors.error, fontSize: 13)),
              data: (tasks) {
                if (_project == null) {
                  return Text('Pick a project first.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                if (tasks.isEmpty) {
                  return Text('No open tasks on this project.',
                      style: Theme.of(context).textTheme.bodySmall);
                }
                return DropdownButtonFormField<String>(
                  initialValue:
                      tasks.any((t) => t.name == _task) ? _task : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Task'),
                  items: tasks
                      .map((t) => DropdownMenuItem(
                          value: t.name, child: Text(t.subject)))
                      .toList(),
                  onChanged: (v) => setState(() => _task = v),
                );
              },
            ),
            const SizedBox(height: AppDimens.lg),
            InkWell(
              onTap: _busy ? null : _pickStart,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start time',
                  prefixIcon: Icon(Icons.schedule),
                ),
                child: Text(_dateFmt.format(_start)),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _hoursCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hours',
                hintText: 'e.g. 1.5',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What did you work on?',
                alignLabelWithHint: true,
                hintText: 'Required — at least 4 characters',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimens.md),
              Text(_error!,
                  style: TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: AppDimens.xl),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save entry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showLogPastTimeSheet(
        BuildContext context, TimesheetContext ctx) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      builder: (_) => LogPastTimeSheet(ctx: ctx),
    );
