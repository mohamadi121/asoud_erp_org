import 'package:asoud_pwa/features/hr/domain/hr_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class HrGateway {
  Future<HrDashboard> loadDashboard(WorkContext context);

  Future<List<HrEmployeeSummary>> loadEmployees(WorkContext context);

  Future<List<WorkReportSummary>> loadWorkReports(WorkContext context);

  Future<List<CommunicationSummary>> loadCommunications(
    WorkContext context, {
    String box = 'inbox',
  });

  Future<String> createWorkReport({
    required String reportDate,
    required String activity,
    required int minutes,
    required String summary,
  });

  Future<String> createCommunication({
    required WorkContext context,
    required String type,
    required String subject,
    required String body,
    required String recipient,
    required String priority,
    required String confidentiality,
  });
}
