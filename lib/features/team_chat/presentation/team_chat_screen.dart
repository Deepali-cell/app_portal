import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/nav_history.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../crm_shared/domain/models.dart' show UserOption;
import '../../home/presentation/app_shell.dart';
import '../application/providers.dart';
import '../domain/models.dart';

/// Internal team chat home: the list of the current user's channels (DMs +
/// groups) with a FAB to start a new direct message or create a group.
class TeamChatScreen extends ConsumerWidget {
  const TeamChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chatChannelsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Team Chat'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(chatChannelsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showNewMenu(context, ref),
        child: Icon(Icons.chat, color: AppColors.onPrimary),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(chatChannelsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(
                child: Text(e is ApiException
                    ? e.message
                    : 'Could not load chats.')),
          ]),
          data: (channels) {
            if (channels.isEmpty) return _empty(context);
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
              itemCount: channels.length,
              separatorBuilder: (_, _) => Divider(
                  height: 1, indent: 76, color: AppColors.outlineVariant),
              itemBuilder: (_, i) => _ChannelTile(channel: channels[i]),
            );
          },
        ),
      ),
      bottomNavigationBar: const PersistentBottomNav(),
    );
  }

  Widget _empty(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.forum_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          Center(
            child: Text('No chats yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Tap the button to message a teammate.',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
        ],
      );

  void _showNewMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_add_alt_1, color: AppColors.primary),
              title: const Text('New direct message'),
              onTap: () {
                Navigator.pop(ctx);
                _startDirect(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.group_add, color: AppColors.primary),
              title: const Text('New group'),
              onTap: () {
                Navigator.pop(ctx);
                _newGroup(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startDirect(BuildContext context, WidgetRef ref) async {
    final user = await showModalBottomSheet<UserOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UserSearchSheet(title: 'Message teammate'),
    );
    if (user == null || !context.mounted) return;
    try {
      final id = await ref.read(teamChatRepositoryProvider).startDirect(user.name);
      ref.invalidate(chatChannelsProvider);
      if (!context.mounted) return;
      context.push(
        Routes.chatThread,
        extra: ChatChannel(
            name: id, channelType: 'Direct', title: user.fullName),
      );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _newGroup(BuildContext context, WidgetRef ref) async {
    // The sheet creates the group itself and returns the new channel, so no
    // record types cross the modal boundary.
    final channel = await showModalBottomSheet<ChatChannel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewGroupSheet(),
    );
    if (channel == null || !context.mounted) return;
    ref.invalidate(chatChannelsProvider);
    context.push(Routes.chatThread, extra: channel);
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});
  final ChatChannel channel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push(Routes.chatThread, extra: channel),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Icon(channel.isGroup ? Icons.groups : Icons.person,
            color: AppColors.primary),
      ),
      title: Text(channel.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        channel.lastMessage ??
            (channel.isGroup ? '${channel.memberCount} members' : 'Tap to chat'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.onSurfaceVariant),
      ),
      trailing: channel.lastAt == null
          ? null
          : Text(_ago(channel.lastAt!),
              style: TextStyle(
                  fontSize: 11, color: AppColors.onSurfaceVariant)),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat('d MMM').format(t.toLocal());
  }
}

/// A search-as-you-type sheet returning one selected user.
class _UserSearchSheet extends ConsumerStatefulWidget {
  const _UserSearchSheet({required this.title});
  final String title;
  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  final _q = TextEditingController();
  List<UserOption> _results = const [];
  bool _loading = false;

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(teamChatRepositoryProvider).searchUsers(txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                children: [
                  Text(widget.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppDimens.sm),
                  TextField(
                    controller: _q,
                    autofocus: true,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final u = _results[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                          u.fullName.isNotEmpty
                              ? u.fullName.characters.first.toUpperCase()
                              : '?',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                    title: Text(u.fullName),
                    subtitle: Text(u.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, u),
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

/// Sheet to name a group and multi-select its members.
class _NewGroupSheet extends ConsumerStatefulWidget {
  const _NewGroupSheet();
  @override
  ConsumerState<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends ConsumerState<_NewGroupSheet> {
  final _name = TextEditingController();
  final _q = TextEditingController();
  final _selected = <String, UserOption>{};
  List<UserOption> _results = const [];
  bool _loading = false;
  bool _creating = false;

  Future<void> _search(String txt) async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(teamChatRepositoryProvider).searchUsers(txt);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _name.dispose();
    _q.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final title = _name.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the group a name.')));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one member.')));
      return;
    }
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final id = await ref
          .read(teamChatRepositoryProvider)
          .createGroup(title, _selected.keys.toList());
      if (!mounted) return;
      Navigator.pop(
        context,
        ChatChannel(
          name: id,
          channelType: 'Group',
          title: title,
          memberCount: _selected.length + 1,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimens.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('New group',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      FilledButton(
                        onPressed: _creating ? null : _done,
                        child: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.sm),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Group name',
                      prefixIcon: const Icon(Icons.groups),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: AppDimens.sm),
                  TextField(
                    controller: _q,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Add people',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            if (_selected.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                  children: [
                    for (final u in _selected.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(u.fullName),
                          onDeleted: () =>
                              setState(() => _selected.remove(u.name)),
                        ),
                      ),
                  ],
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final u = _results[i];
                  final on = _selected.containsKey(u.name);
                  return CheckboxListTile(
                    value: on,
                    title: Text(u.fullName),
                    subtitle: Text(u.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onChanged: (_) => setState(() {
                      if (on) {
                        _selected.remove(u.name);
                      } else {
                        _selected[u.name] = u;
                      }
                    }),
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
