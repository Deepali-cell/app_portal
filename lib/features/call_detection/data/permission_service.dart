import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../domain/permission_status.dart';

/// Wraps permission_handler with our specific permission set + iOS fallback.
///
/// All methods are no-ops on iOS (return notApplicable) because Apple's
/// sandbox prevents call interception entirely.
class CallDetectPermissionService {
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // Storage on Android 11+ needs MANAGE_EXTERNAL_STORAGE, which has no
  // runtime dialog — must open a dedicated Settings screen. The native
  // side (AllFilesAccessHelper) handles both the check and the launch.
  static const _nativeChannel = MethodChannel('tcb_portal/call_detect');

  /// Fetch the current status of a single permission.
  Future<PermissionState> check(CallDetectPermission p) async {
    if (!_isAndroid) return PermissionState.notApplicable;
    if (p == CallDetectPermission.storage) {
      return _checkAllFilesAccess();
    }
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
  /// Storage + SYSTEM_ALERT_WINDOW open a system Settings page rather than
  /// a runtime dialog; state is re-verified when the user returns.
  Future<PermissionState> request(CallDetectPermission p) async {
    if (!_isAndroid) return PermissionState.notApplicable;
    if (p == CallDetectPermission.storage) {
      try {
        await _nativeChannel.invokeMethod('openAllFilesAccessSettings');
      } catch (_) {/* ignore — screen will re-check on resume */}
      return _checkAllFilesAccess();
    }
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

  Future<PermissionState> _checkAllFilesAccess() async {
    try {
      final granted =
          await _nativeChannel.invokeMethod<bool>('hasAllFilesAccess');
      return (granted ?? false)
          ? PermissionState.granted
          : PermissionState.denied;
    } catch (_) {
      return PermissionState.denied;
    }
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
        // Handled via the native MANAGE_EXTERNAL_STORAGE bridge instead of
        // permission_handler; this branch is unreachable in practice.
        return null;
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
