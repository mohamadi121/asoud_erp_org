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
          return http.Response.bytes(
            utf8.encode(jsonEncode({
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
            })),
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
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'message': {
                'company': 'ASOUD',
                'detail_types': ['Employee'],
                'accounts': [],
                'rules': [],
              }
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
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

  test('loads and saves floating detail management data', () async {
    final requests = <http.Request>[];
    final gateway = FrappeOrganizationGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'message': {
                'company': 'ASOUD',
                'holding': 'ASOUD Holding',
                'detail_types': ['Customer'],
                'groups': [
                  {
                    'name': 'CUSTOMERS',
                    'group_title': 'مشتریان',
                    'group_code': 'CUS',
                    'detail_type': 'Customer',
                    'enabled': 1,
                  }
                ],
                'details': [],
              }
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final snapshot = await gateway.loadFloatingDetails(workContext);
    await gateway.saveFloatingDetailGroup(
      workContext,
      const FloatingDetailGroupDraft(
        title: 'مشتریان',
        code: 'CUS',
        detailType: 'Customer',
      ),
    );

    expect(snapshot.groups.single.code, 'CUS');
    expect(
      requests.first.url.path,
      '/api/method/asoud_iran.api.floating_detail_management_snapshot',
    );
    expect(
      requests.last.url.path,
      '/api/method/asoud_iran.api.save_floating_detail_group',
    );
    expect(requests.last.bodyFields['idempotency_key'], isNotEmpty);
  });

  test('saves a fiscal period through an idempotent endpoint', () async {
    late http.Request captured;
    final gateway = FrappeOrganizationGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'message': {
                'settings': {'company': 'ASOUD'},
                'fiscal_years': [],
                'fiscal_periods': [],
                'period_locks': [],
              }
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    await gateway.saveFiscalPeriod(
      workContext,
      const FiscalPeriodDraft(
        fiscalYear: '1406',
        periodName: 'فروردین',
        fromDate: '2027-03-21',
        toDate: '2027-04-20',
      ),
    );

    expect(
      captured.url.path,
      '/api/method/asoud_iran.api.save_fiscal_period',
    );
    expect(captured.bodyFields['idempotency_key'], isNotEmpty);
    final payload =
        jsonDecode(captured.bodyFields['payload']!) as Map<String, dynamic>;
    expect(payload['period_name'], 'فروردین');
  });
}
