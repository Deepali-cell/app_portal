import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/attendance/presentation/attendance_roster_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/lock_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/unlock_screen.dart';
import '../../features/deals/presentation/deal_detail_screen.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/directory/presentation/directory_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/invoices/presentation/invoice_detail_screen.dart';
import '../../features/invoices/presentation/invoices_screen.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/leads/presentation/lead_detail_screen.dart';
import '../../features/leads/presentation/leads_screen.dart';
import '../../features/leave/presentation/leave_detail_screen.dart';
import '../../features/leave/presentation/leave_approvals_screen.dart';
import '../../features/leave/presentation/leave_screen.dart';
import '../../features/approvals/presentation/approval_requests_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/missed_activities/presentation/missed_activities_screen.dart';
import '../../features/pipeline/presentation/pipeline_screen.dart';
import '../../features/team_status/presentation/team_status_screen.dart';
import '../../features/call_detection/presentation/call_detection_screen.dart';
import '../../features/leads_kanban/presentation/kanban_screen.dart';
import '../../features/location_tracking/presentation/person_location_screen.dart';
import '../../features/location_tracking/presentation/team_live_list_screen.dart';
import '../../features/location_tracking/presentation/team_live_map_screen.dart';
import '../../features/sales_workspace/presentation/sales_workspace_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/purchase/presentation/purchase_dashboard_screen.dart';
import '../../features/sales/presentation/sales_dashboard_screen.dart';
import '../../features/records/domain/descriptor.dart';
import '../../features/records/presentation/record_list_screen.dart';
import '../../features/records/presentation/record_detail_screen.dart';
import '../../features/stock/presentation/items_screen.dart';
import '../../features/stock/presentation/item_detail_screen.dart';
import '../../features/stock/presentation/item_create_screen.dart';
import '../../features/stock/presentation/item_edit_screen.dart';
import '../../features/stock/domain/models.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/payslips/presentation/payslip_detail_screen.dart';
import '../../features/payslips/presentation/payslips_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/timesheet/presentation/all_timesheets_screen.dart';
import '../../features/timesheet/presentation/timesheet_detail_screen.dart';
import '../../features/timesheet/presentation/timesheet_screen.dart';
import '../config/app_config.dart';

class Routes {
  Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const unlock = '/unlock';

  // All top-level destinations - drawer + side-rail navigation; no nested "More".
  static const home = '/home';
  static const time = '/time';
  static const leave = '/leave';
  static const payroll = '/payroll';
  static const tasks = '/tasks';
  static const timesheet = '/timesheet';
  static const allTimesheets = '/hr/all-timesheets';
  static const expenses = '/expenses';
  static const leads = '/leads';
  static const deals = '/deals';
  static const directory = '/directory';
  static const invoices = '/invoices';
  static const stock = '/stock';
  static const admin = '/admin';
  // Manufacturing
  static const mfgBom = '/mfg/bom';
  static const mfgWorkOrder = '/mfg/work-order';
  static const mfgJobCard = '/mfg/job-card';
  static const mfgProductionPlan = '/mfg/production-plan';
  static const mfgWorkstation = '/mfg/workstation';
  // Stock (transactional + masters)
  static const stockWarehouse = '/stock/warehouse';
  static const stockMaterialRequest = '/stock/material-request';
  static const stockEntry = '/stock/entry';
  // Purchase
  static const purchaseDashboard = '/purchase/dashboard';
  static const purchaseSupplier = '/purchase/supplier';
  static const purchaseRfq = '/purchase/rfq';
  static const purchaseSupplierQuotation = '/purchase/supplier-quotation';
  static const purchaseOrder = '/purchase/order';
  static const purchaseReceipt = '/purchase/receipt';
  static const salesDashboard = '/sales/dashboard';
  static const salesCustomer = '/sales/customer';
  static const salesQuotation = '/sales/quotation';
  static const salesOrder = '/sales/order';
  static const salesDelivery = '/sales/delivery';
  // HR
  static const hrEmployees = '/hr/employees';
  static const allAttendance = '/hr/all-attendance';
  static const hrAttendance = '/hr/attendance-management';
  static const approvals = '/hr/approvals';
  // Projects
  static const projectsProject = '/projects/project';
  // Shared generic record detail
  static const recordDetail = '/record-detail';

  // Sub-routes pushed inside a branch
  static const payslipDetail = '/payslip-detail';
  static const leadDetail = '/lead-detail';
  static const dealDetail = '/deal-detail';
  static const timesheetDetail = '/timesheet-detail';
  static const invoiceDetail = '/invoice-detail';
  static const stockItemDetail = '/stock-item-detail';
  static const stockItemCreate = '/stock-item-create';
  static const stockItemEdit = '/stock-item-edit';
  static const leaveDetail = '/leave-detail';
  static const leaveApprovals = '/leave-approvals';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const missedActivities = '/missed-activities';
  static const leaderboard = '/leaderboard';
  static const pipeline = '/pipeline';
  static const teamStatus = '/team-status';
  static const callDetection = '/call-detection';
  static const leadKanban = '/lead-kanban';
  static const salesWorkspace = '/sales-workspace';
  // Live location tracking (Phase LOC.1)
  static const locationTeam = '/location/team';        // list view (landing)
  static const locationTeamMap = '/location/team/map'; // map of all pins
  static const locationPerson = '/location/person/:employee';

  // Legacy aliases (kept so old strings still resolve)
  static const attendance = time;
  static const payslips = payroll;
  static const more = home;
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final unlocked = ref.read(sessionUnlockedProvider);
      final loc = state.matchedLocation;

      switch (auth.status) {
        case AuthStatus.unknown:
          return loc == Routes.splash ? null : Routes.splash;
        case AuthStatus.unauthenticated:
          return loc == Routes.login ? null : Routes.login;
        case AuthStatus.authenticated:
          final mustUnlock = AppConfig.biometricLockEnabled && !unlocked;
          if (mustUnlock) return loc == Routes.unlock ? null : Routes.unlock;
          const transient = {Routes.splash, Routes.login, Routes.unlock};
          return transient.contains(loc) ? Routes.home : null;
      }
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.unlock, builder: (_, _) => const UnlockScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.time, builder: (_, _) => const AttendanceScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.allAttendance,
              builder: (_, _) => const AttendanceRosterScreen(
                title: 'All Attendance',
                canManage: false,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.hrAttendance,
              builder: (_, _) => const AttendanceRosterScreen(
                title: 'Attendance Management',
                canManage: true,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.leave, builder: (_, _) => const LeaveScreen()),
            GoRoute(
              path: Routes.leaveDetail,
              builder: (_, state) =>
                  LeaveDetailScreen(name: state.extra! as String),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.approvals,
              // `?tab=` deep-links to a section: 0 Leave, 1 Comp-Off, 2 Expense.
              builder: (_, state) => ApprovalRequestsScreen(
                initialTab:
                    int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.payroll, builder: (_, _) => const PayslipsScreen()),
            GoRoute(
              path: Routes.payslipDetail,
              builder: (_, state) =>
                  PayslipDetailScreen(name: state.extra! as String),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.tasks, builder: (_, _) => const TasksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.timesheet, builder: (_, _) => const TimesheetScreen()),
            GoRoute(
              path: Routes.timesheetDetail,
              builder: (_, state) =>
                  TimesheetDetailScreen(name: state.extra! as String),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.allTimesheets,
              builder: (_, _) => const AllTimesheetsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.expenses, builder: (_, _) => const ExpensesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.leads, builder: (_, _) => const LeadsScreen()),
            GoRoute(
              path: Routes.leadDetail,
              builder: (_, state) =>
                  LeadDetailScreen(name: state.extra! as String),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.deals, builder: (_, _) => const DealsScreen()),
            GoRoute(
              path: Routes.dealDetail,
              builder: (_, state) =>
                  DealDetailScreen(name: state.extra! as String),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.directory,
                builder: (_, _) => const DirectoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.invoices,
                builder: (_, _) => const InvoicesScreen()),
            GoRoute(
              path: Routes.invoiceDetail,
              builder: (_, state) {
                final args = state.extra! as InvoiceDetailArgs;
                return InvoiceDetailScreen(name: args.name, kind: args.kind);
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.stock, builder: (_, _) => const ItemsScreen()),
            GoRoute(
              path: Routes.stockItemDetail,
              builder: (_, state) =>
                  ItemDetailScreen(name: state.extra! as String),
            ),
            GoRoute(
              path: Routes.stockItemCreate,
              builder: (_, _) => const ItemCreateScreen(),
            ),
            GoRoute(
              path: Routes.stockItemEdit,
              builder: (_, state) =>
                  ItemEditScreen(item: state.extra! as ItemDetail),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.admin, builder: (_, _) => const AdminScreen()),
          ]),
          _recordBranch(Routes.mfgBom, 'mfg_bom'),
          _recordBranch(Routes.mfgWorkOrder, 'mfg_work_order'),
          _recordBranch(Routes.mfgJobCard, 'mfg_job_card'),
          _recordBranch(Routes.mfgProductionPlan, 'mfg_production_plan'),
          _recordBranch(Routes.mfgWorkstation, 'mfg_workstation'),
          _recordBranch(Routes.hrEmployees, 'hr_employee'),
          _recordBranch(Routes.projectsProject, 'projects_project'),
          _recordBranch(Routes.stockWarehouse, 'stock_warehouse'),
          _recordBranch(Routes.stockMaterialRequest, 'stock_material_request'),
          _recordBranch(Routes.stockEntry, 'stock_entry'),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.purchaseDashboard,
              builder: (_, _) => const PurchaseDashboardScreen(),
            ),
          ]),
          _recordBranch(Routes.purchaseSupplier, 'purchase_supplier'),
          _recordBranch(Routes.purchaseRfq, 'purchase_rfq'),
          _recordBranch(
              Routes.purchaseSupplierQuotation, 'purchase_supplier_quotation'),
          _recordBranch(Routes.purchaseOrder, 'purchase_order'),
          _recordBranch(Routes.purchaseReceipt, 'purchase_receipt'),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.salesDashboard,
              builder: (_, _) => const SalesDashboardScreen(),
            ),
          ]),
          _recordBranch(Routes.salesCustomer, 'sales_customer'),
          _recordBranch(Routes.salesQuotation, 'sales_quotation'),
          _recordBranch(Routes.salesOrder, 'sales_order'),
          _recordBranch(Routes.salesDelivery, 'sales_delivery'),
        ],
      ),
      GoRoute(
        path: Routes.recordDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            RecordDetailScreen(args: state.extra! as RecordArgs),
      ),
      GoRoute(
          path: Routes.profile,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const ProfileScreen()),
      GoRoute(
          path: Routes.leaveApprovals,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const LeaveApprovalsScreen()),
      GoRoute(
          path: Routes.notifications,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const NotificationsScreen()),
      GoRoute(
          path: Routes.missedActivities,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const MissedActivitiesScreen()),
      GoRoute(
          path: Routes.leaderboard,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const LeaderboardScreen()),
      GoRoute(
          path: Routes.pipeline,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const PipelineScreen()),
      GoRoute(
          path: Routes.teamStatus,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const TeamStatusScreen()),
      GoRoute(
          path: Routes.callDetection,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const CallDetectionScreen()),
      GoRoute(
          path: Routes.leadKanban,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const LeadKanbanScreen()),
      GoRoute(
          path: Routes.salesWorkspace,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const SalesWorkspaceScreen()),
      GoRoute(
          path: Routes.locationTeam,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const TeamLiveListScreen()),
      GoRoute(
          path: Routes.locationTeamMap,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const TeamLiveMapScreen()),
      GoRoute(
          path: Routes.locationPerson,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => PersonLocationScreen(
                employee: Uri.decodeComponent(
                    state.pathParameters['employee'] ?? ''),
              )),
    ],
  );
});

/// A shell branch that hosts a generic [RecordListScreen] for the descriptor
/// registered under [key]. Keeps the router terse as modules grow.
StatefulShellBranch _recordBranch(String path, String key) {
  final descriptor = recordRegistry[key]!;
  return StatefulShellBranch(routes: [
    GoRoute(
      path: path,
      builder: (_, _) => RecordListScreen(descriptor: descriptor),
    ),
  ]);
}

/// Bridges Riverpod state changes to GoRouter's redirect re-evaluation.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(sessionUnlockedProvider, (_, _) => notifyListeners());
  }
}
