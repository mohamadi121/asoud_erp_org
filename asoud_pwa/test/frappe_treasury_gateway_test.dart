import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/treasury/data/frappe_treasury_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads company and branch scoped treasury dashboard', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'message': {
            'as_of_date': '2027-05-10',
            'totals': {'Bank': 87, 'Cash': 14, 'Petty Cash': 4},
            'accounts': [
              {
                'name': 'BANK-1',
                'account_title': 'بانک اصلی',
                'treasury_type': 'Bank',
                'branch': 'A-HQ',
                'balance': 87,
              }
            ],
            'cheques': {'Incoming:Cleared': 10},
            'unsettled_petty_cash_claims': 2,
          }
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeTreasuryGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final result = await gateway.load(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(captured.url.path, '/api/method/asoud_core.api.treasury_dashboard');
    expect(captured.url.queryParameters, {'company': 'A', 'branch': 'A-HQ'});
    expect(result.bank, 87);
    expect(result.accounts.single.title, 'بانک اصلی');
    expect(result.cheques['Incoming:Cleared'], 10);
    expect(result.unsettledPettyCashClaims, 2);
  });
}
