import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/operations/data/frappe_operations_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads permission-scoped workbench contracts and documents', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': {
              'contracts': [
                {
                  'document_type': 'Sales Invoice',
                  'label': 'صورتحساب فروش',
                  'fields': ['customer', 'posting_date'],
                  'child_table': 'items',
                  'child_fields': ['item_code', 'qty', 'rate'],
                }
              ],
              'documents': [
                {
                  'document_type': 'Sales Invoice',
                  'name': 'SINV-1',
                  'docstatus': 0,
                  'posting_date': '2026-07-26',
                  'grand_total': 100,
                }
              ],
            }
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeOperationsGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final result = await gateway.loadWorkbench(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(
      captured.url.path,
      '/api/method/asoud_core.api.operational_workbench',
    );
    expect(captured.url.queryParameters, {'company': 'A', 'branch': 'A-HQ'});
    expect(result.contracts.single.documentType, 'Sales Invoice');
    expect(result.documents.single.name, 'SINV-1');
    expect(result.documents.single.amount, 100);
  });

  test('creates a draft through the dedicated backend contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'message': {'name': 'SINV-1', 'docstatus': 0}
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeOperationsGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final name = await gateway.createDraft(
      context: const WorkContext(company: 'A', branch: 'A-HQ'),
      documentType: 'Sales Invoice',
      payload: {
        'customer': 'CUST-1',
        'items': [
          {'item_code': 'ITEM-1', 'qty': 1, 'rate': 10}
        ],
      },
    );

    expect(name, 'SINV-1');
    expect(captured.method, 'POST');
    expect(captured.bodyFields['company'], 'A');
    expect(captured.bodyFields['branch'], 'A-HQ');
    expect(captured.bodyFields['document_type'], 'Sales Invoice');
    expect(captured.bodyFields['idempotency_key']!.length, greaterThan(16));
  });

  test('loads permission-filtered options for a typed Link field', () async {
    late http.Request captured;
    final gateway = FrappeOperationsGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': [
                {'value': 'CUST-1', 'label': 'CUST-1'}
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final options = await gateway.linkOptions(
      documentType: 'Sales Invoice',
      fieldname: 'customer',
      search: 'CUST',
    );

    expect(options, ['CUST-1']);
    expect(
      captured.url.path,
      '/api/method/asoud_core.api.operational_link_options',
    );
    expect(captured.url.queryParameters['fieldname'], 'customer');
    expect(captured.url.queryParameters['search'], 'CUST');
  });
}
