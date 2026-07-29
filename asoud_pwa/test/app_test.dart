import 'package:asoud_pwa/app/shell/asoud_app.dart';
import 'package:asoud_pwa/features/session/domain/session_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_gateway.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_models.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_snapshot.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_gateway.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSessionGateway implements SessionGateway {
  WorkContext? activated;

  @override
  Future<List<WorkContext>> login(
          {required String username, required String password}) async =>
      const [
        WorkContext(
            company: 'Sample Company', branch: 'HQ', branchName: 'Head Office')
      ];

  @override
  Future<void> activateContext(WorkContext context) async {
    activated = context;
  }
}

class FakeAccountingGateway implements IranAccountingGateway {
  @override
  Future<List<Map<String, dynamic>>> loadClosingRuns(String company) async =>
      const [];

  @override
  Future<Map<String, dynamic>> loadNumberingOverview(String company) async => {
        'counts': {
          'Temporary': 0,
          'Final': 0,
          'Locked': 0,
          'Cancelled': 0,
        }
      };
  @override
  Future<AccountingSettings> applySetup(String company) =>
      loadSettings(company);

  @override
  Future<String> convertAmount({
    required String value,
    required String inputUnit,
    required String outputUnit,
  }) async =>
      '10000 IRR';

  @override
  Future<String> fromJalali(String value) async => '2026-03-21';

  @override
  Future<List<AccountSummary>> loadChartOfAccounts(String company) async =>
      const [
        AccountSummary(
          name: '111001 - Cash',
          number: '111001',
          title: 'Cash',
          rootType: 'Asset',
          isGroup: false,
        ),
      ];

  @override
  Future<AccountingSettings> loadSettings(String company) async =>
      AccountingSettings(
        company: company,
        setupStatus: 'Completed',
        coaTemplate: 'ASOUD-IR-GENERAL-V1.1.0',
        setupVersion: '1.1.0',
        baseCurrency: 'IRR',
        amountInputUnit: 'TOMAN',
        calendarDisplay: 'Jalali',
      );

  @override
  Future<List<TrialBalanceRow>> loadTrialBalance({
    required String company,
    required String fromDate,
    required String toDate,
  }) async =>
      const [];
}

class FakeOperationsGateway implements OperationsGateway {
  @override
  Future<List<String>> eligibleFloatingDetails({
    required WorkContext context,
    required String account,
    String search = '',
  }) async =>
      const [];

  @override
  Future<List<String>> linkOptions({
    required String documentType,
    required String fieldname,
    String search = '',
    bool child = false,
  }) async =>
      const [];

  @override
  Future<OperationsSnapshot> load(WorkContext context) async =>
      const OperationsSnapshot(
        sales: 100,
        purchases: 50,
        receipts: 100,
        payments: 50,
        stockQty: 10,
        stockValue: 1000,
      );

  @override
  Future<OperationalWorkbench> loadWorkbench(WorkContext context) async =>
      const OperationalWorkbench(contracts: [], documents: []);

  @override
  Future<String> createDraft({
    required WorkContext context,
    required String documentType,
    required Map<String, dynamic> payload,
  }) async =>
      'DRAFT-1';

  @override
  Future<void> transition({
    required String documentType,
    required String name,
    required String action,
    String reason = '',
  }) async {}
}

class FakeTreasuryGateway implements TreasuryGateway {
  @override
  Future<TreasurySnapshot> load(WorkContext context) async =>
      const TreasurySnapshot(
        asOfDate: '2027-05-10',
        bank: 87000,
        cash: 14900,
        pettyCash: 4000,
        accounts: [],
        cheques: {'Incoming:Cleared': 10000, 'Outgoing:Cleared': 3000},
        unsettledPettyCashClaims: 0,
      );
}

class FakeDashboardGateway implements DashboardGateway {
  @override
  Future<void> markNotificationRead(String name) async {}

  @override
  Future<DashboardSnapshot> load(WorkContext context) async =>
      const DashboardSnapshot(
        asOfDate: '2026-07-26',
        generatedAt: '2026-07-26 12:00:00',
        currency: 'IRR',
        cards: [
          DashboardMetric(key: 'sales_today', value: 100, trend: 10),
          DashboardMetric(key: 'receipts_today', value: 80, trend: 5),
          DashboardMetric(key: 'payments_today', value: 40, trend: -2),
          DashboardMetric(key: 'bank_balance', value: 87000),
          DashboardMetric(key: 'cash_balance', value: 14900),
          DashboardMetric(key: 'petty_cash_balance', value: 4000),
        ],
        cashFlow: [],
        incomeMix: [],
        recentOperations: [],
        approvals: [],
        incomingApprovalCount: 0,
        outgoingApprovalCount: 0,
        notifications: [],
        quickCreateContracts: [],
      );
}

void main() {
  testWidgets('renders the Persian login shell', (tester) async {
    await tester.pumpWidget(
      AsoudApp(
        sessionGateway: FakeSessionGateway(),
        accountingGateway: FakeAccountingGateway(),
        operationsGateway: FakeOperationsGateway(),
        treasuryGateway: FakeTreasuryGateway(),
        dashboardGateway: FakeDashboardGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u0622\u0633\u0648\u062f ERP'), findsOneWidget);
    expect(
        find.text(
            '\u0648\u0631\u0648\u062f \u0628\u0647 \u0633\u0627\u0645\u0627\u0646\u0647'),
        findsOneWidget);
    expect(find.text('\u0646\u0627\u0645 \u06a9\u0627\u0631\u0628\u0631\u06cc'),
        findsOneWidget);
    expect(find.text('\u0631\u0645\u0632 \u0639\u0628\u0648\u0631'),
        findsOneWidget);
  });

  testWidgets(
      'persists the selected company and branch before opening workspace',
      (tester) async {
    final gateway = FakeSessionGateway();
    await tester.pumpWidget(
      AsoudApp(
        sessionGateway: gateway,
        accountingGateway: FakeAccountingGateway(),
        operationsGateway: FakeOperationsGateway(),
        treasuryGateway: FakeTreasuryGateway(),
        dashboardGateway: FakeDashboardGateway(),
      ),
    );

    await tester.enterText(
      find.widgetWithText(
          TextField, '\u0646\u0627\u0645 \u06a9\u0627\u0631\u0628\u0631\u06cc'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(
          TextField, '\u0631\u0645\u0632 \u0639\u0628\u0648\u0631'),
      'secret',
    );
    await tester.tap(find.text('\u0648\u0631\u0648\u062f'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u0627\u062f\u0627\u0645\u0647'));
    await tester.pumpAndSettle();

    expect(gateway.activated?.company, 'Sample Company');
    expect(gateway.activated?.branch, 'HQ');
    expect(find.text('داشبورد مدیریتی'), findsOneWidget);
    expect(find.text('Sample Company - Head Office'), findsOneWidget);
  });

  testWidgets('shows bank, cash and petty cash treasury balances',
      (tester) async {
    final gateway = FakeSessionGateway();
    await tester.pumpWidget(
      AsoudApp(
        sessionGateway: gateway,
        accountingGateway: FakeAccountingGateway(),
        operationsGateway: FakeOperationsGateway(),
        treasuryGateway: FakeTreasuryGateway(),
        dashboardGateway: FakeDashboardGateway(),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'نام کاربری'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'رمز عبور'),
      'secret',
    );
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('خزانه‌داری'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خزانه‌داری'));
    await tester.pumpAndSettle();

    expect(find.text('بانک'), findsOneWidget);
    expect(find.text('صندوق'), findsOneWidget);
    expect(find.text('تنخواه'), findsOneWidget);
    expect(find.text('87000'), findsOneWidget);
    expect(find.text('14900'), findsOneWidget);
    expect(find.text('4000'), findsOneWidget);
  });
}
