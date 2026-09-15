import 'package:flutter/foundation.dart';

@immutable
class AdminScreenRef {
  const AdminScreenRef(
      {required this.key, required this.doctype, required this.label});
  final String key;
  final String doctype;
  final String label;

  factory AdminScreenRef.fromJson(Map<String, dynamic> j) => AdminScreenRef(
        key: j['key'] as String,
        doctype: j['doctype'] as String,
        label: j['label'] as String,
      );
}

@immutable
class AdminModule {
  const AdminModule({required this.module, required this.screens});
  final String module;
  final List<AdminScreenRef> screens;

  factory AdminModule.fromJson(Map<String, dynamic> j) => AdminModule(
        module: j['module'] as String,
        screens: ((j['screens'] as List?) ?? const [])
            .map((e) => AdminScreenRef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

@immutable
class AdminMeta {
  const AdminMeta({required this.roles, required this.modules});
  final List<String> roles;
  final List<AdminModule> modules;

  factory AdminMeta.fromJson(Map<String, dynamic> j) => AdminMeta(
        roles: ((j['roles'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        modules: ((j['modules'] as List?) ?? const [])
            .map((e) => AdminModule.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// One doctype's permission flags for a role at permlevel 0.
@immutable
class PermFlags {
  const PermFlags({
    this.read = false,
    this.create = false,
    this.write = false,
    this.submit = false,
    this.delete = false,
    this.ifOwner = false,
  });

  final bool read;
  final bool create;
  final bool write;
  final bool submit;
  final bool delete;
  final bool ifOwner;

  bool byType(String t) => switch (t) {
        'read' => read,
        'create' => create,
        'write' => write,
        'submit' => submit,
        'delete' => delete,
        'if_owner' => ifOwner,
        _ => false,
      };

  factory PermFlags.fromJson(Map<String, dynamic> j) => PermFlags(
        read: (j['read'] ?? 0) == 1,
        create: (j['create'] ?? 0) == 1,
        write: (j['write'] ?? 0) == 1,
        submit: (j['submit'] ?? 0) == 1,
        delete: (j['delete'] ?? 0) == 1,
        ifOwner: (j['if_owner'] ?? 0) == 1,
      );
}
