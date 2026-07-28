import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';

abstract interface class IranAccountingGateway {
  Future<AccountingSettings> loadSettings(String company);

  Future<AccountingSettings> applySetup(String company);

  Future<List<AccountSummary>> loadChartOfAccounts(String company);

  Future<String> convertAmount({
    required String value,
    required String inputUnit,
    required String outputUnit,
  });

  Future<String> fromJalali(String value);

  Future<List<TrialBalanceRow>> loadTrialBalance({
    required String company,
    required String fromDate,
    required String toDate,
  });

  Future<Map<String, dynamic>> loadNumberingOverview(String company);

  Future<List<Map<String, dynamic>>> loadClosingRuns(String company);
}
