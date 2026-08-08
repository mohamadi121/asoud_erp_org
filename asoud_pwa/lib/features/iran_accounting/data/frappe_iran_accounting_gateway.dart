import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';

class FrappeIranAccountingGateway implements IranAccountingGateway {
  const FrappeIranAccountingGateway(this._client);

  final AsoudApiClient _client;

  Map<String, dynamic> _message(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is! Map) {
      throw const AsoudApiException('پاسخ حسابداری ایران معتبر نیست.');
    }
    return Map<String, dynamic>.from(message);
  }

  @override
  Future<AccountingSettings> loadSettings(String company) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.company_accounting_settings',
      {'company': company},
    );
    return AccountingSettings.fromJson(_message(response));
  }

  @override
  Future<AccountingSettings> applySetup(String company) async {
    await _client.postForm(
      '/api/method/asoud_iran.api.apply_iran_setup',
      {'company': company},
    );
    return loadSettings(company);
  }

  @override
  Future<List<AccountSummary>> loadChartOfAccounts(String company) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.company_chart_of_accounts',
      {'company': company},
    );
    final message = response['message'];
    if (message is! List) {
      throw const AsoudApiException('ساختار نمودار حساب‌ها معتبر نیست.');
    }
    return message
        .whereType<Map>()
        .map((row) => AccountSummary.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<String> convertAmount({
    required String value,
    required String inputUnit,
    required String outputUnit,
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.convert_amount',
      {
        'value': value,
        'input_unit': inputUnit,
        'output_unit': outputUnit,
      },
    );
    final message = _message(response);
    return '${message['amount']} ${message['unit']}';
  }

  @override
  Future<String> fromJalali(String value) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.from_jalali',
      {'jalali_date': value},
    );
    return _message(response)['gregorian']?.toString() ?? '';
  }

  @override
  Future<List<TrialBalanceRow>> loadTrialBalance({
    required String company,
    required String fromDate,
    required String toDate,
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.accounting_trial_balance',
      {'company': company, 'from_date': fromDate, 'to_date': toDate},
    );
    final message = response['message'];
    if (message is! List) {
      throw const AsoudApiException('ساختار تراز آزمایشی معتبر نیست.');
    }
    return message
        .whereType<Map>()
        .map((row) => TrialBalanceRow.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> loadNumberingOverview(String company) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.numbering_overview',
      {'company': company},
    );
    return _message(response);
  }

  @override
  Future<NumberingWorkspace> loadNumberingWorkspace(
    String company, {
    String? postingDate,
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.document_consolidation_workspace',
      {
        'company': company,
        if (postingDate != null && postingDate.isNotEmpty)
          'posting_date': postingDate,
      },
    );
    return NumberingWorkspace.fromJson(_message(response));
  }

  @override
  Future<String> finalizeNumbering({
    required String company,
    required String fiscalYear,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    final response = await _client.postForm(
      '/api/method/asoud_core.api.final_number',
      {
        'company': company,
        'fiscal_year': fiscalYear,
        'from_date': fromDate,
        'to_date': toDate,
        'reason': reason,
      },
    );
    return response['message']?.toString() ?? '';
  }

  @override
  Future<String> consolidateDocuments({
    required String company,
    required String postingDate,
    required List<String> documents,
    required String reason,
  }) async {
    final response = await _client.postForm(
      '/api/method/asoud_core.api.consolidate_accounting_documents',
      {
        'company': company,
        'posting_date': postingDate,
        'documents': jsonEncode(documents),
        'reason': reason,
        'idempotency_key':
            'merge-${DateTime.now().microsecondsSinceEpoch}-$company',
      },
    );
    final message = _message(response);
    return message['name']?.toString() ?? '';
  }

  @override
  Future<List<Map<String, dynamic>>> loadClosingRuns(String company) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.closing_runs',
      {'company': company},
    );
    final message = response['message'];
    if (message is! List) {
      throw const AsoudApiException('پاسخ عملیات اختتامیه معتبر نیست.');
    }
    return message
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
