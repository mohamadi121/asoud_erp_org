import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/session/data/frappe_session_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads CSRF token after login and sends it on mutations', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/method/login') {
        return http.Response(jsonEncode({'message': 'Logged In'}), 200);
      }
      if (request.url.path ==
          '/api/method/asoud_core.api.session_security_context') {
        return http.Response(
          jsonEncode({
            'message': {'user': 'user@example.test', 'csrf_token': 'csrf-123'}
          }),
          200,
        );
      }
      if (request.url.path ==
          '/api/method/asoud_core.api.accessible_contexts') {
        return http.Response(
          jsonEncode({
            'message': [
              {'company': 'A', 'branch': 'A-HQ'}
            ]
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'message': {'company': 'A', 'branch': 'A-HQ'}
        }),
        200,
      );
    });
    final gateway = FrappeSessionGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    await gateway.login(username: 'user@example.test', password: 'secret');
    await gateway.activateContext(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(requests.map((request) => request.url.path), [
      '/api/method/login',
      '/api/method/asoud_core.api.session_security_context',
      '/api/method/asoud_core.api.accessible_contexts',
      '/api/method/asoud_core.api.set_active_context',
    ]);
    expect(requests.last.headers['X-Frappe-CSRF-Token'], 'csrf-123');
  });

  test('activateContext posts the selected company and branch to Frappe',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
          jsonEncode({
            'message': {'company': 'A', 'branch': 'A-HQ'}
          }),
          200);
    });
    final gateway = FrappeSessionGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    await gateway.activateContext(
      const WorkContext(
          company: 'A', branch: 'A-HQ', branchName: 'Head Office'),
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/method/asoud_core.api.set_active_context');
    expect(captured.bodyFields, {'company': 'A', 'branch': 'A-HQ'});
  });

  test('activateContext omits branch for company-wide context', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
          jsonEncode({
            'message': {'company': 'A', 'branch': null}
          }),
          200);
    });
    final gateway = FrappeSessionGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    await gateway.activateContext(const WorkContext(company: 'A'));

    expect(captured.bodyFields, {'company': 'A'});
  });
}
