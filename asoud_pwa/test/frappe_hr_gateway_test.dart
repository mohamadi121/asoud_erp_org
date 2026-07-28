import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/hr/data/frappe_hr_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads branch-scoped HR dashboard', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': {
              'cards': {
                'active_employees': 12,
                'today_reports': 8,
                'missing_reports': 4,
                'open_communications': 3,
                'open_actions': 2,
              },
              'my': {'open_actions': 1, 'unread_notifications': 5},
            }
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeHrGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final result = await gateway.loadDashboard(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(captured.url.path, '/api/method/asoud_hr.api.dashboard');
    expect(captured.url.queryParameters, {'company': 'A', 'branch': 'A-HQ'});
    expect(result.activeEmployees, 12);
    expect(result.missingReports, 4);
    expect(result.unreadNotifications, 5);
  });

  test('creates a daily report through idempotent HR contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': {
              'name': 'HR-RPT-2026-00001',
              'status': 'Draft',
            }
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeHrGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final name = await gateway.createWorkReport(
      reportDate: '2026-07-26',
      activity: 'Implementation',
      minutes: 90,
      summary: 'Completed HR module',
    );

    expect(captured.url.path, '/api/method/asoud_hr.api.save_work_report');
    expect(captured.bodyFields['request_key']!.length, greaterThan(16));
    final data =
        jsonDecode(captured.bodyFields['data']!) as Map<String, dynamic>;
    expect(data['report_date'], '2026-07-26');
    expect((data['activities'] as List).single['duration_minutes'], 90);
    expect(name, 'HR-RPT-2026-00001');
  });
}
