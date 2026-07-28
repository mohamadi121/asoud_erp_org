import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/dashboard/data/frappe_dashboard_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads one permission-scoped aggregate dashboard response', () async {
    late Uri requested;
    final client = AsoudApiClient(
      baseUrl: 'https://erp.example',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'message': {
              'as_of_date': '2026-07-26',
              'generated_at': '2026-07-26 12:00:00',
              'currency': 'IRR',
              'cards': [
                {'key': 'sales_today', 'value': 125, 'trend': 25}
              ],
              'cash_flow': [],
              'income_mix': [],
              'recent_operations': [],
              'approval_inbox': {
                'items': [],
                'counts': {'incoming': 2, 'outgoing': 1}
              },
              'notifications': [],
              'quick_create_contracts': [],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await FrappeDashboardGateway(client).load(
      const WorkContext(
        company: 'شرکت آسود',
        branch: 'BR-1',
        branchName: 'دفتر مرکزی',
      ),
    );

    expect(
      requested.path,
      '/api/method/asoud_core.api.dashboard_workspace',
    );
    expect(requested.queryParameters['company'], 'شرکت آسود');
    expect(requested.queryParameters['branch'], 'BR-1');
    expect(result.metric('sales_today').value, 125);
    expect(result.incomingApprovalCount, 2);
  });

  test('marks only the selected dashboard notification as read', () async {
    late http.Request captured;
    final gateway = FrappeDashboardGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {'name': 'NOTIF-1', 'read': 1}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await gateway.markNotificationRead('NOTIF-1');

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/method/asoud_core.api.mark_dashboard_notification_read',
    );
    expect(captured.bodyFields['name'], 'NOTIF-1');
  });
}
