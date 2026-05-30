import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../auth/domain/profile.dart';

@immutable
class NavDest {
  const NavDest(this.label, this.icon, this.selectedIcon, this.route, this.cap);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final String? cap;
}

/// Single source of truth for the app's primary destinations. Drives the
/// scrollable bottom nav (mobile) and the persistent side rail (tablet+).
const List<NavDest> _allDestinations = [
  NavDest('Home', Icons.dashboard_outlined, Icons.dashboard, Routes.home, null),
  NavDest('Time', Icons.schedule_outlined, Icons.schedule, Routes.time, 'attendance'),
  NavDest('Leave', Icons.event_outlined, Icons.event, Routes.leave, 'leave'),
  NavDest('Payroll', Icons.payments_outlined, Icons.payments, Routes.payroll, 'payslip'),
  NavDest('Tasks', Icons.task_alt_outlined, Icons.task_alt, Routes.tasks, 'task'),
  NavDest('Timesheet', Icons.access_time_outlined, Icons.access_time, Routes.timesheet, 'timesheet'),
  NavDest('Expenses', Icons.receipt_long_outlined, Icons.receipt_long, Routes.expenses, 'expense'),
  NavDest('Leads', Icons.person_search_outlined, Icons.person_search, Routes.leads, 'leads'),
  NavDest('Deals', Icons.handshake_outlined, Icons.handshake, Routes.deals, 'deals'),
  NavDest('Directory', Icons.contacts_outlined, Icons.contacts, Routes.directory, null),
  NavDest('Invoices', Icons.receipt_outlined, Icons.receipt, Routes.invoices, 'invoices'),
];

List<NavDest> destinationsFor(Profile? profile) {
  if (profile == null) return _allDestinations;
  return _allDestinations.where((d) => d.cap == null || profile.can(d.cap!)).toList();
}

/// Treat sub-routes as belonging to their parent for highlight purposes.
bool isInBranch(String dest, String current) {
  if (current == dest) return true;
  const childMap = {
    Routes.payroll: Routes.payslipDetail,
    Routes.leads: Routes.leadDetail,
    Routes.deals: Routes.dealDetail,
    Routes.timesheet: Routes.timesheetDetail,
    Routes.invoices: Routes.invoiceDetail,
  };
  return childMap[dest] == current;
}
