import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/hr/domain/hr_gateway.dart';
import 'package:asoud_pwa/features/hr/domain/hr_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeHrGateway implements HrGateway {
  const FrappeHrGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<HrDashboard> loadDashboard(WorkContext context) async =>
      HrDashboard.fromJson(
        _messageMap(await _client.getQuery(
          '/api/method/asoud_hr.api.dashboard',
          _contextQuery(context),
        )),
      );

  @override
  Future<List<HrEmployeeSummary>> loadEmployees(WorkContext context) async {
    final message = _messageMap(await _client.getQuery(
      '/api/method/asoud_hr.api.employees',
      _contextQuery(context),
    ));
    return _items(message)
        .map(HrEmployeeSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<WorkReportSummary>> loadWorkReports(WorkContext context) async {
    final message = _messageMap(await _client.getQuery(
      '/api/method/asoud_hr.api.work_reports',
      _contextQuery(context),
    ));
    return _items(message)
        .map(WorkReportSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<CommunicationSummary>> loadCommunications(
    WorkContext context, {
    String box = 'inbox',
  }) async {
    final message = _messageMap(await _client.getQuery(
      '/api/method/asoud_hr.api.communications',
      {..._contextQuery(context), 'box': box},
    ));
    return _items(message)
        .map(CommunicationSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<String> createWorkReport({
    required String reportDate,
    required String activity,
    required int minutes,
    required String summary,
  }) async {
    final response = await _client.postForm(
      '/api/method/asoud_hr.api.save_work_report',
      {
        'request_key': _requestKey('report'),
        'data': jsonEncode({
          'report_date': reportDate,
          'summary': summary,
          'activities': [
            {
              'activity_title': activity,
              'duration_minutes': minutes,
              'progress': 100,
            }
          ],
        }),
      },
    );
    return _messageMap(response)['name']?.toString() ?? '';
  }

  @override
  Future<String> createCommunication({
    required WorkContext context,
    required String type,
    required String subject,
    required String body,
    required String recipient,
    required String priority,
    required String confidentiality,
  }) async {
    final response = await _client.postForm(
      '/api/method/asoud_hr.api.create_communication',
      {
        'request_key': _requestKey('communication'),
        'data': jsonEncode({
          'communication_type': type,
          'company': context.company,
          if (context.branch != null) 'branch': context.branch,
          'subject': subject,
          'body': body,
          'priority': priority,
          'confidentiality': confidentiality,
          'recipients': [
            {
              'recipient_type': 'User',
              'user': recipient,
              'delivery_mode': 'To',
            }
          ],
        }),
      },
    );
    return _messageMap(response)['name']?.toString() ?? '';
  }

  Map<String, String> _contextQuery(WorkContext context) => {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      };

  Map<String, dynamic> _messageMap(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ ماژول منابع انسانی معتبر نیست.');
    }
    return message;
  }

  Iterable<Map<String, dynamic>> _items(Map<String, dynamic> message) {
    final items = message['items'];
    if (items is! List<dynamic>) {
      throw const AsoudApiException('فهرست منابع انسانی معتبر نیست.');
    }
    return items.whereType<Map<String, dynamic>>();
  }

  String _requestKey(String operation) =>
      'pwa-hr-$operation-${DateTime.now().microsecondsSinceEpoch}';
}
