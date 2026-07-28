class HrDashboard {
  const HrDashboard({
    required this.activeEmployees,
    required this.todayReports,
    required this.missingReports,
    required this.openCommunications,
    required this.openActions,
    required this.myOpenActions,
    required this.unreadNotifications,
  });

  factory HrDashboard.fromJson(Map<String, dynamic> json) {
    final cards = json['cards'] as Map<String, dynamic>? ?? const {};
    final my = json['my'] as Map<String, dynamic>? ?? const {};
    return HrDashboard(
      activeEmployees: _integer(cards['active_employees']),
      todayReports: _integer(cards['today_reports']),
      missingReports: _integer(cards['missing_reports']),
      openCommunications: _integer(cards['open_communications']),
      openActions: _integer(cards['open_actions']),
      myOpenActions: _integer(my['open_actions']),
      unreadNotifications: _integer(my['unread_notifications']),
    );
  }

  final int activeEmployees;
  final int todayReports;
  final int missingReports;
  final int openCommunications;
  final int openActions;
  final int myOpenActions;
  final int unreadNotifications;
}

class HrEmployeeSummary {
  const HrEmployeeSummary({
    required this.name,
    required this.employeeName,
    required this.status,
    this.department,
    this.designation,
  });

  factory HrEmployeeSummary.fromJson(Map<String, dynamic> json) =>
      HrEmployeeSummary(
        name: json['name']?.toString() ?? '',
        employeeName: json['employee_name']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        department: json['department']?.toString(),
        designation: json['designation']?.toString(),
      );

  final String name;
  final String employeeName;
  final String status;
  final String? department;
  final String? designation;
}

class WorkReportSummary {
  const WorkReportSummary({
    required this.name,
    required this.employeeName,
    required this.reportDate,
    required this.status,
    required this.totalMinutes,
    this.approvalStatus,
  });

  factory WorkReportSummary.fromJson(Map<String, dynamic> json) =>
      WorkReportSummary(
        name: json['name']?.toString() ?? '',
        employeeName: json['employee_name']?.toString() ?? '',
        reportDate: json['report_date']?.toString() ?? '',
        status: json['workflow_status']?.toString() ?? '',
        totalMinutes: _integer(json['total_minutes']),
        approvalStatus: json['asoud_approval_status']?.toString(),
      );

  final String name;
  final String employeeName;
  final String reportDate;
  final String status;
  final int totalMinutes;
  final String? approvalStatus;
}

class CommunicationSummary {
  const CommunicationSummary({
    required this.name,
    required this.type,
    required this.subject,
    required this.sender,
    required this.priority,
    required this.confidentiality,
    required this.status,
  });

  factory CommunicationSummary.fromJson(Map<String, dynamic> json) =>
      CommunicationSummary(
        name: json['name']?.toString() ?? '',
        type: json['communication_type']?.toString() ?? '',
        subject: json['subject']?.toString() ?? '',
        sender: json['sender']?.toString() ?? '',
        priority: json['priority']?.toString() ?? '',
        confidentiality: json['confidentiality']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );

  final String name;
  final String type;
  final String subject;
  final String sender;
  final String priority;
  final String confidentiality;
  final String status;
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
