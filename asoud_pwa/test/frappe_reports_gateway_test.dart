import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/reports/data/frappe_reports_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads canonical branch-scoped accounting report', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': {
              'report_type': 'trial_balance',
              'title': 'تراز آزمایشی شش‌ستونی',
              'from_date_jalali': '1405-01-01',
              'to_date_jalali': '1405-12-29',
              'currency': 'IRR',
              'columns': [
                {'key': 'account', 'label': 'حساب', 'type': 'text'}
              ],
              'rows': [
                {'account': 'بانک'}
              ],
              'totals': {'period_debit': 100, 'period_credit': 100},
              'checksum': 'abc',
            }
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final gateway = FrappeReportsGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test', client: client),
    );

    final report = await gateway.load(
      context: const WorkContext(company: 'A', branch: 'A-HQ'),
      reportType: 'trial_balance',
      fromDate: '2026-03-21',
      toDate: '2027-03-20',
    );

    expect(
      captured.url.path,
      '/api/method/asoud_iran.api.standard_accounting_report',
    );
    expect(captured.url.queryParameters['company'], 'A');
    expect(captured.url.queryParameters['branch'], 'A-HQ');
    expect(report.title, 'تراز آزمایشی شش‌ستونی');
    expect(report.rows.single['account'], 'بانک');
  });

  test('builds an encoded authenticated export URL', () {
    final gateway = FrappeReportsGateway(
      AsoudApiClient(baseUrl: 'https://erp.example.test'),
    );

    final url = Uri.parse(
      gateway.exportUrl(
        context: const WorkContext(company: 'شرکت الف', branch: 'مرکز'),
        reportType: 'journal',
        fromDate: '2026-03-21',
        toDate: '2027-03-20',
        fileFormat: 'pdf',
      ),
    );

    expect(url.path, '/api/method/asoud_iran.api.export_accounting_report');
    expect(url.queryParameters['company'], 'شرکت الف');
    expect(url.queryParameters['branch'], 'مرکز');
    expect(url.queryParameters['file_format'], 'pdf');
  });
}
