import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/reports/domain/reports_gateway.dart';
import 'package:asoud_pwa/features/reports/domain/standard_report.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeReportsGateway implements ReportsGateway {
  const FrappeReportsGateway(this._client);

  final AsoudApiClient _client;

  Map<String, String> _query({
    required WorkContext context,
    required String reportType,
    required String fromDate,
    required String toDate,
    String? fileFormat,
  }) =>
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
        'report_type': reportType,
        'from_date': fromDate,
        'to_date': toDate,
        if (fileFormat != null) 'file_format': fileFormat,
      };

  @override
  Future<StandardReport> load({
    required WorkContext context,
    required String reportType,
    required String fromDate,
    required String toDate,
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.standard_accounting_report',
      _query(
        context: context,
        reportType: reportType,
        fromDate: fromDate,
        toDate: toDate,
      ),
    );
    final message = response['message'];
    if (message is! Map) {
      throw const AsoudApiException('پاسخ گزارش استاندارد معتبر نیست.');
    }
    return StandardReport.fromJson(Map<String, dynamic>.from(message));
  }

  @override
  String exportUrl({
    required WorkContext context,
    required String reportType,
    required String fromDate,
    required String toDate,
    required String fileFormat,
  }) {
    final uri = Uri.parse(
      '${_client.baseUrl}/api/method/asoud_iran.api.export_accounting_report',
    ).replace(
      queryParameters: _query(
        context: context,
        reportType: reportType,
        fromDate: fromDate,
        toDate: toDate,
        fileFormat: fileFormat,
      ),
    );
    return uri.toString();
  }
}
