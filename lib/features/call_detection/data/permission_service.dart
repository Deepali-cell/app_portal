import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;

import '../domain/permission_status.dart';

/// Wraps permission_handler with our specific permission set + iOS fallback.
///
/// All methods are no-ops on iOS (return notApplicable) because Apple's
/// sandbox prevents call interception entirely.
class CallDetectPermissionService {
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Fetch the current status of a single permission.
  Future<PermissionState> check(CallDetectPermission p) async {
    if (!_isAndroid) return PermissionState.notApplicable;
    final perm = _map(p);
    if (perm == null) return PermissionState.notApplicable;
    final status = await perm.status;
    return _fromHandler(status);
  }

  Future<List<CallDetectStatus>> checkAll() async {
    return Future.wait(
      CallDetectPermission.values.map((p) async =>
          CallDetectStatus(permission: p, state: await check(p))),
    );
  }

  /// Request a permission. Returns the new state after the dialog flow.
  /// SYSTEM_ALERT_WINDOW opens system Settings rather than a dialog.
  Future<PermissionState> request(CallDetectPermission p) async {
    if (!_isAndroid) return PermissionState.notApplicable;
    final perm = _map(p);
    if (perm == null) return PermissionState.notApplicable;
    final newStatus = await perm.request();
    return _fromHandler(newStatus);
  }

  /// Open the app's system Settings page (for permanentlyDenied recovery).
  Future<bool> openSystemAppSettings() async {
    if (!_isAndroid) return false;
    return ph.openAppSettings();
  }

  // ---- internals ----

  ph.Permission? _map(CallDetectPermission p) {
    switch (p) {
      case CallDetectPermission.phoneState:
      case CallDetectPermission.callLog:
        // permission_handler bundles READ_PHONE_STATE + READ_CALL_LOG under
        // Permission.phone. The native module in D.2.2 will explicitly
        // request READ_CALL_LOG via a platform channel if OEM requires it.
        return ph.Permission.phone;
      case CallDetectPermission.storage:
        return ph.Permission.storage;
      case CallDetectPermission.systemAlertWindow:
        return ph.Permission.systemAlertWindow;
      case CallDetectPermission.notifications:
        return ph.Permission.notification;
    }
  }

  PermissionState _fromHandler(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isRestricted) {
      return PermissionState.granted;
    }
    if (s.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }
}

/// Probes whether the running device is on the supported OEM list for
/// OEM-recorder-folder scraping (Phase D.2.4).
class DeviceSupportProbe {
  static const _supportedBrands = {
    'samsung', 'vivo', 'realme', 'oppo', 'xiaomi', 'redmi',
    'poco', 'motorola', 'moto',
  };
  static const _unsupportedBrands = {
    'google', 'nothing', 'oneplus',
  };

  /// Returns (supported, hintText).
  static (bool, String) probe(String? brand, String? model) {
    final b = (brand ?? '').toLowerCase().trim();
    final m = (model ?? '').trim();
    final brandLabel = brand ?? 'Unknown';
    final hint = m.isEmpty ? brandLabel : '$brandLabel $m';
    if (_unsupportedBrands.any((x) => b.contains(x))) {
      return (false, '$hint: OEM call recording not supported');
    }
    if (_supportedBrands.any((x) => b.contains(x))) {
      return (true, '$hint: supported');
    }
    return (true, '$hint: likely supported, will verify');
  }
}
