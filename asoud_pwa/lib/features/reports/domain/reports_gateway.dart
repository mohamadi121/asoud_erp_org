import 'package:asoud_pwa/features/reports/domain/standard_report.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class ReportsGateway {
  Future<StandardReport> load({
    required WorkContext context,
    required String reportType,
    required String fromDate,
    required String toDate,
  });

  String exportUrl({
    required WorkContext context,
    required String reportType,
    required String fromDate,
    required String toDate,
    required String fileFormat,
  });
}
