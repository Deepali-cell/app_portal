import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../invoices/domain/models.dart' show InvoiceKind;
import '../../invoices/presentation/invoice_detail_screen.dart'
    show InvoiceDetailArgs;
import '../domain/models.dart';

/// Open the document the notification refers to.
///
/// Maps Frappe DocType -> mobile route. Returns true if a route was pushed,
/// false if the notification has no destination (in which case the caller
/// should fall back to just marking it read).
///
/// Unknown DocTypes return false instead of guessing — better to do nothing
/// than to land the user on the wrong screen.
bool openNotificationTarget(BuildContext context, NotificationItem item) {
  final docType = item.documentType;
  final docName = item.documentName;
  if (docType == null || docName == null || docName.isEmpty) return false;

  switch (docType) {
    case 'Leave Application':
      context.push(Routes.leaveDetail, extra: docName);
      return true;
    case 'Salary Slip':
      context.push(Routes.payslipDetail, extra: docName);
      return true;
    case 'Sales Invoice':
      context.push(
        Routes.invoiceDetail,
        extra: InvoiceDetailArgs(name: docName, kind: InvoiceKind.sales),
      );
      return true;
    case 'Purchase Invoice':
      context.push(
        Routes.invoiceDetail,
        extra: InvoiceDetailArgs(name: docName, kind: InvoiceKind.purchase),
      );
      return true;
    case 'Lead':
      context.push(Routes.leadDetail, extra: docName);
      return true;
    case 'CRM Deal':
      context.push(Routes.dealDetail, extra: docName);
      return true;
    case 'Timesheet':
      context.push(Routes.timesheetDetail, extra: docName);
      return true;
    // DocTypes without a dedicated detail screen — land on the list.
    case 'Task':
      context.go(Routes.tasks);
      return true;
    case 'ToDo':
      context.go(Routes.tasks);
      return true;
    case 'Expense Claim':
      context.go(Routes.expenses);
      return true;
    case 'Payment Entry':
      context.go(Routes.invoices);
      return true;
    case 'Employee Checkin':
      context.go(Routes.time);
      return true;
    case 'Employee':
      context.go(Routes.directory);
      return true;
    default:
      return false;
  }
}
