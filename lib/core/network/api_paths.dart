/// Frappe REST/RPC endpoint paths used by the app.
class ApiPaths {
  ApiPaths._();

  // Auth
  static const String login = '/api/method/login';
  static const String logout = '/api/method/logout';
  static const String credentials =
      '/api/method/tcb_portal_erp.api.auth.get_credentials';
  static const String profile =
      '/api/method/tcb_portal_erp.api.auth.get_profile';
  static const String profileUpdate =
      '/api/method/tcb_portal_erp.api.auth.update_my_profile';

  // Directory
  static const String directoryList =
      '/api/method/tcb_portal_erp.api.directory.list_employees';

  // Invoices
  static const String invoicesContext =
      '/api/method/tcb_portal_erp.api.invoices.get_context';
  static const String customerSearch =
      '/api/method/tcb_portal_erp.api.invoices.search_customers';
  static const String supplierSearch =
      '/api/method/tcb_portal_erp.api.invoices.search_suppliers';
  static const String itemSearch =
      '/api/method/tcb_portal_erp.api.invoices.search_items';
  static const String salesInvoiceCreate =
      '/api/method/tcb_portal_erp.api.invoices.create_sales_invoice';
  static const String purchaseInvoiceCreate =
      '/api/method/tcb_portal_erp.api.invoices.create_purchase_invoice';
  static const String invoiceDetail =
      '/api/method/tcb_portal_erp.api.invoices.get_invoice_detail';
  static const String invoiceSubmit =
      '/api/method/tcb_portal_erp.api.invoices.submit_invoice';
  static const String modesOfPayment =
      '/api/method/tcb_portal_erp.api.invoices.list_modes_of_payment';
  static const String recordPayment =
      '/api/method/tcb_portal_erp.api.invoices.record_payment';
  static const String paymentsList =
      '/api/method/tcb_portal_erp.api.invoices.list_payments';

  // Attendance
  static const String attendanceContext =
      '/api/method/tcb_portal_erp.api.attendance.get_context';
  static const String attendanceMark =
      '/api/method/tcb_portal_erp.api.attendance.mark';

  // Leave
  static const String leaveContext =
      '/api/method/tcb_portal_erp.api.leave.get_context';
  static const String leaveApply = '/api/method/tcb_portal_erp.api.leave.apply';
  static const String compOffApply =
      '/api/method/tcb_portal_erp.api.leave.apply_comp_off';

  // Expenses
  static const String expenseContext =
      '/api/method/tcb_portal_erp.api.expense.get_context';
  static const String expenseApply =
      '/api/method/tcb_portal_erp.api.expense.apply';

  // Payslips
  static const String payslipList =
      '/api/method/tcb_portal_erp.api.payslip.get_list';
  static const String payslipDetail =
      '/api/method/tcb_portal_erp.api.payslip.get_detail';

  // Tasks
  static const String taskContext =
      '/api/method/tcb_portal_erp.api.task.get_context';
  static const String taskCreate = '/api/method/tcb_portal_erp.api.task.create';
  static const String taskSetStatus =
      '/api/method/tcb_portal_erp.api.task.set_status';

  // Timesheet
  static const String timesheetContext =
      '/api/method/tcb_portal_erp.api.timesheet.get_context';
  static const String timesheetDetail =
      '/api/method/tcb_portal_erp.api.timesheet.get_detail';
  static const String timesheetCreate =
      '/api/method/tcb_portal_erp.api.timesheet.create';
  static const String timesheetSubmit =
      '/api/method/tcb_portal_erp.api.timesheet.submit_timesheet';
  static const String activeTimer =
      '/api/method/tcb_portal_erp.api.timesheet.get_active_timer';
  static const String timerStart =
      '/api/method/tcb_portal_erp.api.timesheet.start_timer';
  static const String timerStop =
      '/api/method/tcb_portal_erp.api.timesheet.stop_timer';
  static const String projectTasks =
      '/api/method/tcb_portal_erp.api.timesheet.get_project_tasks';

  // CRM Leads
  static const String leadsContext =
      '/api/method/tcb_portal_erp.api.leads.get_context';
  static const String leadDetail =
      '/api/method/tcb_portal_erp.api.leads.get_detail';
  static const String leadCreate = '/api/method/tcb_portal_erp.api.leads.create';
  static const String leadUpdate = '/api/method/tcb_portal_erp.api.leads.update';
  static const String leadConvert =
      '/api/method/tcb_portal_erp.api.leads.convert_to_deal';

  // CRM Deals
  static const String dealsContext =
      '/api/method/tcb_portal_erp.api.deals.get_context';
  static const String dealDetail =
      '/api/method/tcb_portal_erp.api.deals.get_detail';
  static const String dealUpdate = '/api/method/tcb_portal_erp.api.deals.update';

  // File upload
  static const String uploadFile = '/api/method/upload_file';

  // Push notifications (device token registration)
  static const String registerDevice =
      '/api/method/tcb_portal_erp.api.notifications.register_device';
  static const String unregisterDevice =
      '/api/method/tcb_portal_erp.api.notifications.unregister_device';

  // CRM collaboration (Notes / Tasks / Comments / Attachments / Assignees)
  static const String notesList = '/api/method/tcb_portal_erp.api.notes.list_notes';
  static const String noteCreate = '/api/method/tcb_portal_erp.api.notes.create_note';
  static const String noteUpdate = '/api/method/tcb_portal_erp.api.notes.update_note';
  static const String noteDelete = '/api/method/tcb_portal_erp.api.notes.delete_note';

  static const String crmTasksList =
      '/api/method/tcb_portal_erp.api.crm_tasks.list_tasks';
  static const String crmTaskCreate =
      '/api/method/tcb_portal_erp.api.crm_tasks.create_task';
  static const String crmTaskUpdate =
      '/api/method/tcb_portal_erp.api.crm_tasks.update_task';
  static const String crmTaskDelete =
      '/api/method/tcb_portal_erp.api.crm_tasks.delete_task';

  static const String commentsList =
      '/api/method/tcb_portal_erp.api.comments.list_comments';
  static const String commentCreate =
      '/api/method/tcb_portal_erp.api.comments.create_comment';
  static const String commentDelete =
      '/api/method/tcb_portal_erp.api.comments.delete_comment';

  static const String attachmentsList =
      '/api/method/tcb_portal_erp.api.attachments.list_attachments';
  static const String attachmentDelete =
      '/api/method/tcb_portal_erp.api.attachments.delete_attachment';

  static const String assigneesList =
      '/api/method/tcb_portal_erp.api.assignments.list_assignees';
  static const String assigneeAdd =
      '/api/method/tcb_portal_erp.api.assignments.add_assignee';
  static const String assigneeRemove =
      '/api/method/tcb_portal_erp.api.assignments.remove_assignee';
  static const String userSearch =
      '/api/method/tcb_portal_erp.api.assignments.search_assignable_users';

  // CRM Calls (CRM Call Log)
  static const String crmCallsList =
      '/api/method/tcb_portal_erp.api.crm_calls.list_calls';
  static const String crmCallCreate =
      '/api/method/tcb_portal_erp.api.crm_calls.create_call';
  static const String crmCallDelete =
      '/api/method/tcb_portal_erp.api.crm_calls.delete_call';

  // Emails (Communication) - list + compose+send
  static const String emailsList =
      '/api/method/tcb_portal_erp.api.emails.list_emails';
  static const String emailSend =
      '/api/method/tcb_portal_erp.api.emails.send_email';

  // Events (calendar)
  static const String eventsList =
      '/api/method/tcb_portal_erp.api.events.list_events';
  static const String eventCreate =
      '/api/method/tcb_portal_erp.api.events.create_event';
  static const String eventUpdate =
      '/api/method/tcb_portal_erp.api.events.update_event';
  static const String eventDelete =
      '/api/method/tcb_portal_erp.api.events.delete_event';

  // Activity timeline (aggregated)
  static const String timelineGet =
      '/api/method/tcb_portal_erp.api.timeline.get_timeline';

  // Generic resource access
  static String resource(String doctype) => '/api/resource/$doctype';
  static String resourceItem(String doctype, String name) =>
      '/api/resource/$doctype/${Uri.encodeComponent(name)}';

  // RPC
  static String method(String dotted) => '/api/method/$dotted';
}
