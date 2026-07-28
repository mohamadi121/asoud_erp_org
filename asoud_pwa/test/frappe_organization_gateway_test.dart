import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/organization_settings/data/frappe_organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const workContext = WorkContext(company: 'ASOUD');

  test('loads company-scoped accounts and detail rules', () async {
    late http.Request captured;
    final gateway = FrappeOrganizationGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'company': 'ASOUD',
                'detail_types': ['Customer'],
                'floating_details': [
                  {
                    'name': 'FD-1',
                    'detail_title': 'مشتری نمونه',
                    'detail_type': 'Customer',
                  }
                ],
                'accounts': [
                  {
                    'name': 'Receivable - ASOUD',
                    'account_name': 'دریافتنی تجاری',
                    'account_number': '120101',
                    'parent_account': 'Current Assets - ASOUD',
                    'root_type': 'Asset',
                    'report_type': 'Balance Sheet',
                    'account_type': 'Receivable',
                    'account_currency': 'IRR',
                    'is_group': 0,
                    'disabled': 0,
                  }
                ],
                'rules': [
                  {
                    'account': 'Receivable - ASOUD',
                    'detail_type': 'Customer',
                    'required': 1,
                    'enabled': 1,
                  }
                ],
              }
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final snapshot = await gateway.loadAccountRules(workContext);

    expect(captured.method, 'GET');
    expect(
      captured.url.path,
      '/api/method/asoud_iran.api.account_detail_rules_snapshot',
    );
    expect(captured.url.queryParameters['company'], 'ASOUD');
    expect(snapshot.accounts.single.accountNumber, '120101');
    expect(snapshot.rules['Receivable - ASOUD']!.single.required, isTrue);
    expect(snapshot.floatingDetails.single['name'], 'FD-1');
  });

  test('saves account and its detail rules in one idempotent request',
      () async {
    late http.Request captured;
    final gateway = FrappeOrganizationGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'company': 'ASOUD',
                'detail_types': ['Employee'],
                'accounts': [],
                'rules': [],
              }
            }),
            200,
          );
        }),
      ),
    );

    await gateway.saveChartAccount(
      workContext,
      const ChartAccountDraft(
        accountName: 'تنخواه دفتر مرکزی',
        accountNumber: '111003',
        parentAccount: 'Cash - ASOUD',
        accountType: 'Cash',
        rules: [
          AccountDetailRuleDraft(
            detailType: 'Employee',
            required: true,
          ),
        ],
      ),
    );

    final payload =
        jsonDecode(captured.bodyFields['payload']!) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(
      captured.url.path,
      '/api/method/asoud_iran.api.save_chart_account',
    );
    expect(captured.bodyFields['company'], 'ASOUD');
    expect(captured.bodyFields['idempotency_key'], isNotEmpty);
    expect(payload['account_number'], '111003');
    expect((payload['rules'] as List).single['detail_type'], 'Employee');
    expect((payload['rules'] as List).single['required'], isTrue);
  });
}
