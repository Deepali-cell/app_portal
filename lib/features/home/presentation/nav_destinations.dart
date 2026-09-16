import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../auth/domain/profile.dart';

@immutable
class NavDest {
  const NavDest(this.label, this.icon, this.selectedIcon, this.route, this.cap, [this.module]);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final String? cap;
  /// Groups this destination under a module tile (e.g. "HR", "Stock").
  /// `null` keeps it as a top-level item alongside the module tiles (Home).
  final String? module;
}

/// Icon/label shown for a module's own nav tile, keyed by [NavDest.module].
const Map<String, (IconData, IconData, String)> moduleMeta = {
  'HR': (Icons.groups_outlined, Icons.groups, 'HR'),
  'CRM': (Icons.handshake_outlined, Icons.handshake, 'CRM'),
  'Finance': (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Finance'),
  'Stock': (Icons.inventory_2_outlined, Icons.inventory_2, 'Stock'),
  'Manufacturing': (Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, 'Manufacturing'),
  'Projects': (Icons.folder_open_outlined, Icons.folder, 'Projects'),
  'Admin': (Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin'),
};

/// Single source of truth for the app's primary destinations. Drives the
/// scrollable bottom nav (mobile) and the persistent side rail (tablet+).
const List<NavDest> _allDestinations = [
  NavDest('Home', Icons.dashboard_outlined, Icons.dashboard, Routes.home, null),
  NavDest('Time', Icons.schedule_outlined, Icons.schedule, Routes.time, 'attendance', 'HR'),
  NavDest('Leave', Icons.event_outlined, Icons.event, Routes.leave, 'leave', 'HR'),
  NavDest('Payroll', Icons.payments_outlined, Icons.payments, Routes.payroll, 'payslip', 'HR'),
  NavDest('Tasks', Icons.task_alt_outlined, Icons.task_alt, Routes.tasks, 'task', 'HR'),
  NavDest('Timesheet', Icons.access_time_outlined, Icons.access_time, Routes.timesheet, 'timesheet', 'HR'),
  NavDest('Expenses', Icons.receipt_long_outlined, Icons.receipt_long, Routes.expenses, 'expense', 'HR'),
  NavDest('Directory', Icons.contacts_outlined, Icons.contacts, Routes.directory, null, 'HR'),
  NavDest('Leads', Icons.person_search_outlined, Icons.person_search, Routes.leads, 'leads', 'CRM'),
  NavDest('Deals', Icons.handshake_outlined, Icons.handshake, Routes.deals, 'deals', 'CRM'),
  NavDest('Sales', Icons.insights_outlined, Icons.insights, Routes.salesWorkspace, 'sees_sales', 'CRM'),
  NavDest('Invoices', Icons.receipt_outlined, Icons.receipt, Routes.invoices, 'invoices', 'Finance'),
  NavDest('Items', Icons.inventory_2_outlined, Icons.inventory_2, Routes.stock, 'stock_item', 'Stock'),
  NavDest('Warehouses', Icons.warehouse_outlined, Icons.warehouse, Routes.stockWarehouse, 'stock_warehouse', 'Stock'),
  NavDest('Material Req', Icons.playlist_add_outlined, Icons.playlist_add, Routes.stockMaterialRequest, 'purchase_material_request', 'Stock'),
  NavDest('Stock Entry', Icons.swap_horiz_outlined, Icons.swap_horiz, Routes.stockEntry, 'stock_entry', 'Stock'),
  NavDest('BOM', Icons.account_tree_outlined, Icons.account_tree, Routes.mfgBom, 'mfg_bom', 'Manufacturing'),
  NavDest('Work Orders', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing, Routes.mfgWorkOrder, 'mfg_work_order', 'Manufacturing'),
  NavDest('Job Cards', Icons.assignment_outlined, Icons.assignment, Routes.mfgJobCard, 'mfg_job_card', 'Manufacturing'),
  NavDest('Prod. Plan', Icons.event_note_outlined, Icons.event_note, Routes.mfgProductionPlan, 'mfg_production_plan', 'Manufacturing'),
  NavDest('Workstations', Icons.hardware_outlined, Icons.hardware, Routes.mfgWorkstation, 'mfg_workstation', 'Manufacturing'),
  NavDest('Projects', Icons.folder_open_outlined, Icons.folder, Routes.projectsProject, 'projects_project', 'Projects'),
  NavDest('Admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, Routes.admin, 'admin', 'Admin'),
];

List<NavDest> destinationsFor(Profile? profile) {
  if (profile == null) return _allDestinations;
  return _allDestinations.where((d) => d.cap == null || profile.can(d.cap!)).toList();
}

/// Distinct module keys present in [dests], in first-seen order.
List<String> modulesIn(List<NavDest> dests) {
  final seen = <String>{};
  final order = <String>[];
  for (final d in dests) {
    final m = d.module;
    if (m != null && seen.add(m)) order.add(m);
  }
  return order;
}

/// The module the current route belongs to, or null if it's a top-level
/// (module == null) destination such as Home.
String? activeModuleFor(List<NavDest> dests, String currentRoute) {
  for (final d in dests) {
    if (isInBranch(d.route, currentRoute)) return d.module;
  }
  return null;
}

/// Treat sub-routes as belonging to their parent for highlight purposes.
bool isInBranch(String dest, String current) {
  if (current == dest) return true;
  const childMap = {
    Routes.payroll: [Routes.payslipDetail],
    Routes.leads: [Routes.leadDetail],
    Routes.deals: [Routes.dealDetail],
    Routes.timesheet: [Routes.timesheetDetail],
    Routes.invoices: [Routes.invoiceDetail],
    Routes.leave: [Routes.leaveDetail],
    Routes.stock: [Routes.stockItemDetail],
    Routes.salesWorkspace: [
      Routes.pipeline,
      Routes.teamStatus,
      Routes.leaderboard,
      Routes.leadKanban,
      Routes.locationTeam,
    ],
  };
  return childMap[dest]?.contains(current) ?? false;
}
