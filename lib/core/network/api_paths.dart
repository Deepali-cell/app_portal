/// Frappe REST/RPC endpoint paths used by the app.
class ApiPaths {
  ApiPaths._();

  // Tenant resolution (middleware on `TCB_MIDDLEWARE_URL`, NOT the tenant's
  // own ERPNext). Called only on login to look up the tenant's server URL
  // and brand colours by Company ID.
  static const String tenantResolve =
      '/api/method/tcb_portal_control.api.tenant.resolve';

  // Today's Plan - salesperson's daily command-centre payload
  static const String todaysPlan =
      '/api/method/tcb_portal_erp.api.todays_plan.get_today_plan';

  // Post-call outcome capture (Phase A.4)
  static const String callLogOutcome =
      '/api/method/tcb_portal_erp.api.crm_calls.log_outcome';

  // Manager leaderboard (Phase A.7)
  static const String leaderboard =
      '/api/method/tcb_portal_erp.api.leaderboard.get_leaderboard';

  // Lookup CRM Lead / Deal by phone number (Phase D.1)
  static const String lookupByPhone =
      '/api/method/tcb_portal_erp.api.call_lookup.lookup_by_phone';

  // CRM pipeline / funnel dashboard (Runo R.14)
  static const String leadPipeline =
      '/api/method/tcb_portal_erp.api.pipeline.get_lead_pipeline';
  static const String dealPipeline =
      '/api/method/tcb_portal_erp.api.pipeline.get_deal_pipeline';

  // Manager-only live team status (Runo R.6)
  static const String teamStatus =
      '/api/method/tcb_portal_erp.api.team_status.get_team_status';

  // Sales dashboard (Phase L.6)
  static const String salesDashboard =
      '/api/method/tcb_portal_erp.api.dashboard.get_sales_dashboard';

  // Role-specific home sections - one endpoint per role. Each takes a
  // `period` (today | week | month | custom) and optional from_date/to_date.
  static const String hrDashboard =
      '/api/method/tcb_portal_erp.api.hr_dashboard.get_summary';
  static const String projectsDashboard =
      '/api/method/tcb_portal_erp.api.projects_dashboard.get_summary';
  static const String accountsDashboard =
      '/api/method/tcb_portal_erp.api.accounts_dashboard.get_summary';

  // Live location tracking (Phase LOC.1)
  static const String locSetTrackingEnabled =
      '/api/method/tcb_portal_erp.api.location_tracking.set_tracking_enabled';
  static const String locTrackingStatus =
      '/api/method/tcb_portal_erp.api.location_tracking.get_tracking_status';
  static const String locRecordPing =
      '/api/method/tcb_portal_erp.api.location_tracking.record_ping';
  static const String locRecordPingsBatch =
      '/api/method/tcb_portal_erp.api.location_tracking.record_pings_batch';
  static const String locRecordHeartbeat =
      '/api/method/tcb_portal_erp.api.location_tracking.record_heartbeat';
  static const String locMyTeamLive =
      '/api/method/tcb_portal_erp.api.location_tracking.my_team_live';
  static const String locPersonCurrent =
      '/api/method/tcb_portal_erp.api.location_tracking.person_current';
  static const String locPersonTrail =
      '/api/method/tcb_portal_erp.api.location_tracking.person_trail';

  // Call recording + AI pipeline (Phase D.2.4 + D.2.5)
  static const String uploadRecording =
      '/api/method/tcb_portal_erp.api.call_intelligence.upload_recording';
  /// Idempotency lookup - used by the mobile after a multipart-upload
  /// DioException to confirm whether the server already saved the row
  /// (Cloudflare 524 / mobile network drop after server commit).
  static const String findRecordingByClientId =
      '/api/method/tcb_portal_erp.api.call_intelligence.find_by_client_id';
  /// Always-log endpoint - mobile calls this for every detected call
  /// (connected or not) so the user has a complete call history even
  /// when no OEM recording is produced. Auto-matches to a Lead/Deal.
  static const String logCallAttempt =
      '/api/method/tcb_portal_erp.api.call_intelligence.log_call_attempt';
  static const String getRecording =
      '/api/method/tcb_portal_erp.api.call_intelligence.get_recording';
  static const String listRecordingsFor =
      '/api/method/tcb_portal_erp.api.call_intelligence.list_recordings_for';
  static const String applySuggestedStatus =
      '/api/method/tcb_portal_erp.api.call_intelligence.apply_suggested_status';

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
  static const String timesheetAddLog =
      '/api/method/tcb_portal_erp.api.timesheet.add_log';
  static const String timesheetUpdateLog =
      '/api/method/tcb_portal_erp.api.timesheet.update_log';
  static const String timesheetDeleteLog =
      '/api/method/tcb_portal_erp.api.timesheet.delete_log';
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
  // Post-2026-06-29 migration: leads convert to ERPNext Customer (unlocking
  // Quotation → Sales Order → Sales Invoice). The endpoint name kept as
  // convert_to_customer; convert_to_deal is a backwards-compat shim.
  static const String leadConvert =
      '/api/method/tcb_portal_erp.api.leads.convert_to_customer';

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

  // In-app notifications (powered by Frappe's Notification Log)
  static const String notificationsList =
      '/api/method/tcb_portal_erp.api.notifications.list_notifications';
  static const String notificationsUnreadCount =
      '/api/method/tcb_portal_erp.api.notifications.unread_count';
  static const String notificationMarkRead =
      '/api/method/tcb_portal_erp.api.notifications.mark_as_read';
  static const String notificationsMarkAllRead =
      '/api/method/tcb_portal_erp.api.notifications.mark_all_read';

  // Leave detail
  static const String leaveApplicationDetail =
      '/api/method/tcb_portal_erp.api.leave.get_application_detail';
  static const String leavePendingApprovals =
      '/api/method/tcb_portal_erp.api.leave.get_pending_approvals';
  static const String leaveActOnApplication =
      '/api/method/tcb_portal_erp.api.leave.act_on_application';

  // Task detail + update
  static const String taskDetail =
      '/api/method/tcb_portal_erp.api.task.get_detail';
  static const String taskUpdate =
      '/api/method/tcb_portal_erp.api.task.update';

  // Payslip PDF
  static const String payslipDownloadPdf =
      '/api/method/tcb_portal_erp.api.payslip.download_pdf';

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

  // Administrator (in-app Frappe role-permission manager)
  static const String adminMeta =
      '/api/method/tcb_portal_erp.api.admin.get_admin_meta';
  static const String adminRoleMatrix =
      '/api/method/tcb_portal_erp.api.admin.get_role_matrix';
  static const String adminSetPerm =
      '/api/method/tcb_portal_erp.api.admin.set_role_perm';

  // Generic portal records (Manufacturing, HR, Sales, Purchase…)
  static const String portalListDocs =
      '/api/method/tcb_portal_erp.api.portal_docs.list_docs';
  static const String portalGetDoc =
      '/api/method/tcb_portal_erp.api.portal_docs.get_doc';
  // Generic metadata-driven forms
  static const String portalFormMeta =
      '/api/method/tcb_portal_erp.api.portal_forms.get_meta';
  static const String portalSearchLink =
      '/api/method/tcb_portal_erp.api.portal_forms.search_link';
  static const String portalSaveDoc =
      '/api/method/tcb_portal_erp.api.portal_forms.save_doc';
  static const String portalSubmitDoc =
      '/api/method/tcb_portal_erp.api.portal_forms.submit_doc';

  // Stock module (Phase 1)
  static const String stockListItems =
      '/api/method/tcb_portal_erp.api.stock.list_items';
  static const String stockGetItem =
      '/api/method/tcb_portal_erp.api.stock.get_item';

  // Generic resource access
  static String resource(String doctype) => '/api/resource/$doctype';
  static String resourceItem(String doctype, String name) =>
      '/api/resource/$doctype/${Uri.encodeComponent(name)}';

  // RPC
  static String method(String dotted) => '/api/method/$dotted';
}
