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
}
