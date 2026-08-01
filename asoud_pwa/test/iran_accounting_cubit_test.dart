import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/iran_accounting/presentation/bloc/iran_accounting_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = WorkContext(company: 'ASOUD');

  test('loads the company-scoped Iran accounting workspace', () async {
    final gateway = _FakeGateway();
    final cubit = IranAccountingCubit(gateway, context);

    await cubit.load();

    expect(cubit.state.phase, IranAccountingPhase.ready);
    expect(cubit.state.settings?.company, 'ASOUD');
    expect(cubit.state.numberingWorkspace.candidates, hasLength(2));
    await cubit.close();
  });

  test('consolidates two selected documents from the same day', () async {
    final gateway = _FakeGateway();
    final cubit = IranAccountingCubit(
      gateway,
      context,
      initialSection: IranAccountingSection.numbering,
    );
    await cubit.load();
    cubit.toggleDocument('AD-1', true);
    cubit.toggleDocument('AD-2', true);

    await cubit.consolidateSelected('ادغام روزانه');

    expect(gateway.consolidated, ['AD-1', 'AD-2']);
    expect(cubit.state.message, contains('MERGE-1'));
    expect(cubit.state.selectedDocuments, isEmpty);
    await cubit.close();
  });

  test('finalizes numbering and refreshes its overview', () async {
    final gateway = _FakeGateway();
    final cubit = IranAccountingCubit(gateway, context);
    await cubit.load();

    await cubit.finalizeNumbering(
      fiscalYear: '1405',
      fromDate: '2026-03-21',
      toDate: '2026-04-20',
      reason: 'شماره قطعی فروردین',
    );

    expect(gateway.finalizedYear, '1405');
    expect(cubit.state.message, contains('BATCH-1'));
    await cubit.close();
  });
}

class _FakeGateway implements IranAccountingGateway {
  List<String> consolidated = [];
  String? finalizedYear;

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
    consolidated = documents;
    return 'MERGE-1';
  }

  @override
  Future<String> convertAmount({
    required String value,
    required String inputUnit,
    required String outputUnit,
  }) async =>
      '10000 IRR';

  @override
  Future<String> finalizeNumbering({
    required String company,
    required String fiscalYear,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    finalizedYear = fiscalYear;
    return 'BATCH-1';
  }

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
        'counts': {'Temporary': 2, 'Final': 0, 'Locked': 0, 'Cancelled': 0}
      };

  @override
  Future<NumberingWorkspace> loadNumberingWorkspace(
    String company, {
    String? postingDate,
  }) async =>
      NumberingWorkspace(
        company: company,
        postingDate: postingDate ?? '',
        availableDates: const ['2026-03-21'],
        fiscalYears: const [
          FiscalYearOption(
            name: '1405',
            fromDate: '2026-03-21',
            toDate: '2027-03-20',
          ),
        ],
        candidates: consolidated.isEmpty
            ? const [
                NumberingCandidate(
                  name: 'AD-1',
                  postingDate: '2026-03-21',
                  sourceType: 'Journal Entry',
                  sourceName: 'JV-1',
                  temporaryNumber: 'TMP-1',
                ),
                NumberingCandidate(
                  name: 'AD-2',
                  postingDate: '2026-03-21',
                  sourceType: 'Journal Entry',
                  sourceName: 'JV-2',
                  temporaryNumber: 'TMP-2',
                ),
              ]
            : const [],
      );

  @override
  Future<AccountingSettings> loadSettings(String company) async =>
      AccountingSettings(
        company: company,
        setupStatus: 'Completed',
        baseCurrency: 'IRR',
      );

  @override
  Future<List<TrialBalanceRow>> loadTrialBalance({
    required String company,
    required String fromDate,
    required String toDate,
  }) async =>
      const [];
}
