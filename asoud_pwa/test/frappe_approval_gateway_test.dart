import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/approvals/data/frappe_approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads branch-scoped approval inbox', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': {
              'items': [
                {
                  'name': 'APR-REQ-1',
                  'source_doctype': 'Payment Entry',
                  'source_name': 'PAY-1',
                  'company': 'A',
                  'branch': 'A-HQ',
                  'policy': 'APR-POL-1',
                  'amount': 100,
                  'requested_by': 'maker@example.com',
                  'requested_on': '2026-07-26 10:00:00',
                  'status': 'Pending',
                  'current_sequence': 1,
                  'version': '2026-07-26 10:00:00',
                }
              ],
              'counts': {'incoming': 1, 'outgoing': 2},
            }
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeApprovalGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final result = await gateway.loadInbox(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(captured.url.path, '/api/method/asoud_core.api.approval_inbox');
    expect(captured.url.queryParameters, {
      'company': 'A',
      'branch': 'A-HQ',
      'view': 'incoming',
      'limit': '50',
    });
    expect(result.incomingCount, 1);
    expect(result.outgoingCount, 2);
    expect(result.items.single.sourceName, 'PAY-1');
  });

  test('sends idempotent approval action with optimistic version', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': {
              'name': 'APR-REQ-1',
              'source_doctype': 'Payment Entry',
              'source_name': 'PAY-1',
              'company': 'A',
              'policy': 'APR-POL-1',
              'amount': 100,
              'requested_by': 'maker@example.com',
              'requested_on': '2026-07-26 10:00:00',
              'status': 'Approved',
              'current_sequence': 1,
              'version': '2026-07-26 10:01:00',
              'can_act': false,
              'stages': [],
              'actions': [],
            }
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeApprovalGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final result = await gateway.act(
      request: 'APR-REQ-1',
      action: 'Approve',
      comment: '',
      expectedVersion: '2026-07-26 10:00:00',
    );

    expect(
      captured.url.path,
      '/api/method/asoud_core.api.act_on_approval',
    );
    expect(captured.bodyFields['request'], 'APR-REQ-1');
    expect(captured.bodyFields['action'], 'Approve');
    expect(
      captured.bodyFields['expected_version'],
      '2026-07-26 10:00:00',
    );
    expect(captured.bodyFields['idempotency_key']!.length, greaterThan(16));
    expect(result.summary.status, 'Approved');
  });

  test('sends history, search and status filters to the inbox API', () async {
    late http.Request captured;
    final gateway = FrappeApprovalGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'items': [],
                'counts': {'incoming': 0, 'outgoing': 0, 'history': 4},
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final result = await gateway.loadInbox(
      const WorkContext(company: 'A'),
      view: 'history',
      search: 'PAY-1',
      status: 'Approved',
    );

    expect(captured.url.queryParameters['view'], 'history');
    expect(captured.url.queryParameters['search'], 'PAY-1');
    expect(captured.url.queryParameters['status'], 'Approved');
    expect(result.historyCount, 4);
  });

  test('loads the approval policy form workspace', () async {
    late http.Request captured;
    final gateway = FrappeApprovalGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'policies': [],
                'document_types': ['Journal Entry'],
                'branches': [
                  {'name': 'A-HQ', 'branch_name': 'دفتر مرکزی'}
                ],
                'users': [
                  {'name': 'manager@example.com', 'full_name': 'مدیر مالی'}
                ],
                'roles': ['Accounts Manager'],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final workspace = await gateway.loadPolicyWorkspace(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(captured.url.path,
        '/api/method/asoud_core.api.approval_settings_workspace');
    expect(captured.url.queryParameters['company'], 'A');
    expect(workspace.branches['A-HQ'], 'دفتر مرکزی');
    expect(workspace.roles, contains('Accounts Manager'));
  });

  test('saves an approval policy with an idempotency key', () async {
    late http.Request captured;
    final gateway = FrappeApprovalGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'name': 'POL-1',
                'policy_title': 'تأیید سند',
                'document_type': 'Journal Entry',
                'parallel_mode': 'All',
                'minimum_amount': 0,
                'maximum_amount': 0,
                'policy_version': 1,
                'stages': [],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final result = await gateway.savePolicy(
      const WorkContext(company: 'A'),
      const ApprovalPolicyDraft(
        title: 'تأیید سند',
        documentType: 'Journal Entry',
        stages: [
          ApprovalPolicyStage(
            sequence: 1,
            title: 'مدیر',
            approverType: 'Manager',
          ),
        ],
      ),
    );

    expect(
        captured.url.path, '/api/method/asoud_core.api.save_approval_policy');
    expect(captured.bodyFields['company'], 'A');
    expect(captured.bodyFields['idempotency_key'], isNotEmpty);
    final payload = jsonDecode(captured.bodyFields['payload']!);
    expect(payload['stages'][0]['approver_type'], 'Manager');
    expect(result.version, 1);
  });
}
