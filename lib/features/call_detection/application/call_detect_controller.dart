import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_store.dart';
import '../data/permission_service.dart';
import '../domain/permission_status.dart';

final permissionServiceProvider = Provider<CallDetectPermissionService>(
    (ref) => CallDetectPermissionService());

/// Polled snapshot of the call-detection settings UI. autoDispose +
/// invalidate() pattern so the screen always reads fresh permission state
/// when it re-opens (after the user returns from system Settings).
final callDetectSnapshotProvider =
    FutureProvider.autoDispose<CallDetectSnapshot>((ref) async {
  final svc = ref.read(permissionServiceProvider);
  final store = ref.read(secureStoreProvider);

  final enabled = await store.readCallDetectEnabled();
  final perms = await svc.checkAll();

  // Device brand probe — uses Platform info; for richer info we'd add
  // device_info_plus in D.2.2. For now we infer from Platform.operatingSystem.
  String? brand;
  String? model;
  if (!kIsWeb && Platform.isAndroid) {
    brand = Platform.operatingSystemVersion;  // best we can do without device_info
    model = null;
  }
  final (supported, hint) = DeviceSupportProbe.probe(brand, model);

  return CallDetectSnapshot(
    enabled: enabled,
    permissions: perms,
    deviceSupported: supported,
    deviceModelHint: hint,
  );
});

/// Controller for the master toggle + permission requests.
class CallDetectController extends Notifier<bool> {
  @override
  bool build() {
    // Default to false; first read will hydrate via the snapshot provider.
    Future.microtask(() async {
      final stored =
          await ref.read(secureStoreProvider).readCallDetectEnabled();
      state = stored;
    });
    return false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await ref.read(secureStoreProvider).writeCallDetectEnabled(value);
    ref.invalidate(callDetectSnapshotProvider);
  }

  Future<PermissionState> requestPermission(CallDetectPermission p) async {
    final svc = ref.read(permissionServiceProvider);
    final result = await svc.request(p);
    ref.invalidate(callDetectSnapshotProvider);
    return result;
  }

  Future<void> openSystemAppSettings() async {
    await ref.read(permissionServiceProvider).openSystemAppSettings();
    ref.invalidate(callDetectSnapshotProvider);
  }
}

final callDetectControllerProvider =
    NotifierProvider<CallDetectController, bool>(CallDetectController.new);
