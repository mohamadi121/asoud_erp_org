import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/bloc/organization_settings_cubit.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/organization_settings_page.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = WorkContext(company: 'ASOUD');

  test('loads organization snapshot', () async {
    final gateway = _FakeGateway();
    final cubit = OrganizationSettingsCubit(gateway, context);
    await cubit.load();
    expect(cubit.state.phase, OrganizationPhase.ready);
    expect(cubit.state.snapshot.companies.single.title, 'شرکت آسود');
    await cubit.close();
  });

  test('keeps wizard data between steps and saves once', () async {
    final gateway = _FakeGateway();
    final cubit = OrganizationSettingsCubit(gateway, context);
    cubit.start(OrganizationUnitKind.company);
    cubit.update('company_name', 'شرکت جدید');
    cubit.update('abbr', 'NEW');
    cubit.next();
    expect(cubit.state.draft?.step, 1);
    expect(cubit.state.draft?.values['company_name'], 'شرکت جدید');
    expect(await cubit.save(), isTrue);
    expect(gateway.saved, hasLength(1));
    expect(cubit.state.draft, isNull);
    await cubit.close();
  });

  test('loads and saves company financial settings', () async {
    final gateway = _FakeGateway();
    final cubit = OrganizationSettingsCubit(
      gateway,
      context,
      initialView: SettingsView.financial,
    );
    await cubit.load();
    expect(cubit.state.financial?.baseCurrency, 'IRR');
    cubit.updateFinancial(
      coaTemplate: 'GENERAL-V1',
      amountInputUnit: 'TOMAN',
    );
    expect(await cubit.saveFinancial(), isTrue);
    expect(gateway.savedFinancial.single.amountInputUnit, 'TOMAN');
    await cubit.close();
  });

  test('creates a postable account with one required detail rule', () async {
    final gateway = _FakeGateway();
    final cubit = OrganizationSettingsCubit(
      gateway,
      context,
      initialView: SettingsView.financial,
    );
    await cubit.load();
    cubit.startAccount();
    cubit.updateAccount(
      accountName: 'حساب‌های دریافتنی',
      accountNumber: '120101',
      parentAccount: 'Current Assets - ASOUD',
      accountType: 'Receivable',
    );
    cubit.addDetailRule('Customer');
    cubit.updateDetailRule(0, required: true);
    expect(await cubit.saveChartAccount(), isTrue);
    expect(gateway.savedAccounts.single.rules.single.detailType, 'Customer');
    expect(gateway.savedAccounts.single.rules.single.required, isTrue);
    expect(cubit.state.accountDraft, isNull);
    await cubit.close();
  });

  testWidgets('renders settings dashboard and opens unit selector',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationSettingsPage(
            context: context,
            gateway: _FakeGateway(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('داشبورد تنظیمات'), findsWidgets);
    await tester.tap(find.text('واحد سازمانی جدید'));
    await tester.pumpAndSettle();
    expect(find.text('هلدینگ'), findsOneWidget);
    expect(find.text('شرکت یا شخص'), findsOneWidget);
    expect(find.text('شعبه'), findsOneWidget);
  });
}

class _FakeGateway implements OrganizationGateway {
  final saved = <OrganizationDraft>[];
  final savedFinancial = <FinancialSettingsDraft>[];
  final savedAccounts = <ChartAccountDraft>[];

  @override
  Future<OrganizationSnapshot> load(WorkContext context) async =>
      const OrganizationSnapshot(
        companies: [
          OrganizationUnit(
            name: 'ASOUD',
            title: 'شرکت آسود',
            kind: OrganizationUnitKind.company,
          ),
        ],
      );

  @override
  Future<void> save(OrganizationDraft draft) async => saved.add(draft);

  @override
  Future<FinancialSettingsSnapshot> loadFinancial(
    WorkContext context,
  ) async =>
      const FinancialSettingsSnapshot(
        company: 'ASOUD',
        companyName: 'شرکت آسود',
        baseCurrency: 'IRR',
        coaTemplate: 'GENERAL-V1',
        amountInputUnit: 'IRR',
        calendarDisplay: 'Jalali',
        timezone: 'Asia/Tehran',
        setupStatus: 'Completed',
        templates: [
          {
            'name': 'GENERAL-V1',
            'template_title': 'استاندارد عمومی',
            'version': '1',
          },
        ],
      );

  @override
  Future<FinancialSettingsSnapshot> saveFinancial(
    WorkContext context,
    FinancialSettingsDraft draft,
  ) async {
    savedFinancial.add(draft);
    return FinancialSettingsSnapshot(
      company: context.company,
      companyName: 'شرکت آسود',
      baseCurrency: 'IRR',
      coaTemplate: draft.coaTemplate,
      amountInputUnit: draft.amountInputUnit,
      calendarDisplay: draft.calendarDisplay,
      timezone: 'Asia/Tehran',
      setupStatus: 'Completed',
    );
  }

  @override
  Future<AccountRulesSnapshot> loadAccountRules(WorkContext context) async =>
      const AccountRulesSnapshot(
        company: 'ASOUD',
        detailTypes: ['Customer', 'Supplier', 'Employee'],
        accounts: [
          ChartAccount(
            name: 'Current Assets - ASOUD',
            accountName: 'دارایی‌های جاری',
            accountNumber: '12',
            parentAccount: 'Assets - ASOUD',
            rootType: 'Asset',
            reportType: 'Balance Sheet',
            accountType: '',
            accountCurrency: 'IRR',
            isGroup: true,
            disabled: false,
          ),
        ],
      );

  @override
  Future<AccountRulesSnapshot> saveChartAccount(
    WorkContext context,
    ChartAccountDraft draft,
  ) async {
    savedAccounts.add(draft);
    return loadAccountRules(context);
  }
}
