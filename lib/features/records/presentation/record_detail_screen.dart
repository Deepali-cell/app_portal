import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../data/records_repository.dart';
import '../domain/descriptor.dart';
import 'dynamic_form_screen.dart';

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
