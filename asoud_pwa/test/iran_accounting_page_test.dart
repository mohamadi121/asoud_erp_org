import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/iran_accounting/presentation/bloc/iran_accounting_cubit.dart';
import 'package:asoud_pwa/features/iran_accounting/presentation/page/iran_accounting_page.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the dedicated numbering workspace and merges selection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _WidgetGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: IranAccountingPage(
              context: const WorkContext(company: 'ASOUD'),
              gateway: gateway,
              initialSection: IranAccountingSection.numbering,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تخصیص شماره قطعی'), findsOneWidget);
    expect(find.text('ادغام انتخابی اسناد روزانه'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.enterText(
      find.widgetWithText(TextField, 'دلیل ادغام *'),
      'ادغام روزانه تست',
    );
    await tester.tap(find.text('ثبت ادغام روزانه'));
    await tester.pumpAndSettle();

    expect(gateway.merged, isTrue);
    expect(find.textContaining('MERGE-WIDGET'), findsOneWidget);
  });
}

class _WidgetGateway implements IranAccountingGateway {
  bool merged = false;

  @override
  Future<AccountingSettings> applySetup(String company) =>
      loadSettings(company);

  @override
  Future<String> consolidateDocuments({
    required String company,
    required String postingDate,
    required List<String> documents,
    required String reason,
  }) async {
    merged = true;
    return 'MERGE-WIDGET';
  }

  @override
  Future<String> convertAmount(
          {required String value,
          required String inputUnit,
          required String outputUnit}) async =>
      '0';

  @override
  Future<String> finalizeNumbering(
          {required String company,
          required String fiscalYear,
          required String fromDate,
          required String toDate,
          required String reason}) async =>
      'BATCH-WIDGET';

  @override
  Future<String> fromJalali(String value) async => '2026-03-21';

  @override
  Future<List<AccountSummary>> loadChartOfAccounts(String company) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> loadClosingRuns(String company) async =>
      const [];

  @override
  Future<Map<String, dynamic>> loadNumberingOverview(String company) async => {
        'counts': {'Temporary': 2}
      };

  @override
  Future<NumberingWorkspace> loadNumberingWorkspace(String company,
          {String? postingDate}) async =>
      NumberingWorkspace(
        company: company,
        postingDate: postingDate ?? '',
        availableDates: const ['2026-03-21'],
        fiscalYears: const [
          FiscalYearOption(
              name: '1405', fromDate: '2026-03-21', toDate: '2027-03-20')
        ],
        candidates: merged
            ? const []
            : const [
                NumberingCandidate(
                    name: 'AD-1',
                    postingDate: '2026-03-21',
                    sourceType: 'Journal Entry',
                    sourceName: 'JV-1',
                    temporaryNumber: 'TMP-1'),
                NumberingCandidate(
                    name: 'AD-2',
                    postingDate: '2026-03-21',
                    sourceType: 'Journal Entry',
                    sourceName: 'JV-2',
                    temporaryNumber: 'TMP-2'),
              ],
      );

  @override
  Future<AccountingSettings> loadSettings(String company) async =>
      AccountingSettings(
          company: company, setupStatus: 'Completed', baseCurrency: 'IRR');

  @override
  Future<List<TrialBalanceRow>> loadTrialBalance(
          {required String company,
          required String fromDate,
          required String toDate}) async =>
      const [];
}
