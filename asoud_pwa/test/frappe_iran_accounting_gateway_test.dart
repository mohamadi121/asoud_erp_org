import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/iran_accounting/data/frappe_iran_accounting_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads company accounting settings with an encoded company query',
      () async {
    late http.Request captured;
    final gateway = FrappeIranAccountingGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'company': 'Sample Company',
                'setup_status': 'Completed',
                'base_currency': 'IRR',
              }
            }),
            200,
          );
        }),
      ),
    );

    final settings = await gateway.loadSettings('Sample Company');

    expect(captured.method, 'GET');
    expect(
      captured.url.path,
      '/api/method/asoud_iran.api.company_accounting_settings',
    );
    expect(captured.url.queryParameters['company'], 'Sample Company');
    expect(settings.isReady, isTrue);
    expect(settings.baseCurrency, 'IRR');
  });

  test('uses explicit units when converting an amount', () async {
    late http.Request captured;
    final gateway = FrappeIranAccountingGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {'amount': '12505', 'unit': 'IRR'}
            }),
            200,
          );
        }),
      ),
    );

    final result = await gateway.convertAmount(
      value: '1250.5',
      inputUnit: 'TOMAN',
      outputUnit: 'IRR',
    );

    expect(captured.url.queryParameters, {
      'value': '1250.5',
      'input_unit': 'TOMAN',
      'output_unit': 'IRR',
    });
    expect(result, '12505 IRR');
  });

  test('posts an explicit legal numbering range and reason', () async {
    late http.Request captured;
    final gateway = FrappeIranAccountingGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'message': 'NUM-BATCH-0001'}), 200);
        }),
      ),
    );

    final batch = await gateway.finalizeNumbering(
      company: 'Sample Company',
      fiscalYear: '1405',
      fromDate: '2026-03-21',
      toDate: '2026-04-20',
      reason: 'تخصیص ماهانه',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/method/asoud_core.api.final_number');
    expect(captured.bodyFields, {
      'company': 'Sample Company',
      'fiscal_year': '1405',
      'from_date': '2026-03-21',
      'to_date': '2026-04-20',
      'reason': 'تخصیص ماهانه',
    });
    expect(batch, 'NUM-BATCH-0001');
  });

  test('loads the daily consolidation workspace for the active company',
      () async {
    late http.Request captured;
    final gateway = FrappeIranAccountingGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'company': 'Sample Company',
                'posting_date': '2026-03-21',
                'available_dates': ['2026-03-21'],
                'fiscal_years': [
                  {
                    'name': '1405',
                    'from_date': '2026-03-21',
                    'to_date': '2027-03-20',
                  }
                ],
                'candidates': [
                  {
                    'name': 'AD-1',
                    'posting_date': '2026-03-21',
                    'source_doctype': 'Journal Entry',
                    'source_name': 'JV-1',
                    'temporary_number': 'TMP-1',
                  }
                ],
              }
            }),
            200,
          );
        }),
      ),
    );

    final workspace = await gateway.loadNumberingWorkspace(
      'Sample Company',
      postingDate: '2026-03-21',
    );

    expect(captured.method, 'GET');
    expect(
      captured.url.path,
      '/api/method/asoud_core.api.document_consolidation_workspace',
    );
    expect(captured.url.queryParameters, {
      'company': 'Sample Company',
      'posting_date': '2026-03-21',
    });
    expect(workspace.candidates.single.name, 'AD-1');
    expect(workspace.fiscalYears.single.name, '1405');
  });

  test('posts selected same-day documents as a real consolidation', () async {
    late http.Request captured;
    final gateway = FrappeIranAccountingGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'name': 'MERGE-0001',
                'company': 'Sample Company',
                'posting_date': '2026-03-21',
                'document_count': 2,
              }
            }),
            200,
          );
        }),
      ),
    );

    final result = await gateway.consolidateDocuments(
      company: 'Sample Company',
      postingDate: '2026-03-21',
      documents: const ['AD-1', 'AD-2'],
      reason: 'ادغام روزانه',
    );

    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/method/asoud_core.api.consolidate_accounting_documents',
    );
    expect(captured.bodyFields['company'], 'Sample Company');
    expect(captured.bodyFields['posting_date'], '2026-03-21');
    expect(jsonDecode(captured.bodyFields['documents']!), ['AD-1', 'AD-2']);
    expect(captured.bodyFields['reason'], 'ادغام روزانه');
    expect(captured.bodyFields['idempotency_key'], isNotEmpty);
    expect(result, 'MERGE-0001');
  });
}
