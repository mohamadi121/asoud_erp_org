import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/organization_settings/presentation/bloc/organization_settings_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrganizationSettingsPage extends StatelessWidget {
  const OrganizationSettingsPage({
    required this.context,
    required this.gateway,
    this.initialView = SettingsView.dashboard,
    this.initialFinancialSection = FinancialSection.general,
    this.onOpenDestination,
    super.key,
  });

  final WorkContext context;
  final OrganizationGateway gateway;
  final SettingsView initialView;
  final FinancialSection initialFinancialSection;
  final ValueChanged<String>? onOpenDestination;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OrganizationSettingsCubit(
          gateway,
          this.context,
          initialView: initialView,
          initialFinancialSection: initialFinancialSection,
        )..load(),
        child: _OrganizationSettingsView(
          onOpenDestination: onOpenDestination,
        ),
      );
}

class _OrganizationSettingsView extends StatelessWidget {
  const _OrganizationSettingsView({required this.onOpenDestination});

  final ValueChanged<String>? onOpenDestination;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<OrganizationSettingsCubit, OrganizationSettingsState>(
        builder: (context, state) {
          if (state.phase == OrganizationPhase.loading &&
              state.snapshot.companies.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              Column(
                children: [
                  _Header(state: state),
                  if (state.error != null)
                    MaterialBanner(
                      content: Text(state.error!),
                      actions: [
                        TextButton(
                          onPressed:
                              context.read<OrganizationSettingsCubit>().load,
                          child: const Text('تلاش دوباره'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: switch (state.view) {
                      SettingsView.dashboard => _Dashboard(
                          state.snapshot,
                          onOpenDestination: onOpenDestination,
                        ),
                      SettingsView.structure => _Structure(state.snapshot),
                      SettingsView.financial => _FinancialSettings(state),
                    },
                  ),
                ],
              ),
              if (state.draft != null) _Wizard(draft: state.draft!),
              if (state.accountDraft != null)
                _AccountFormDrawer(
                  draft: state.accountDraft!,
                  snapshot: state.accountRules!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
              if (state.detailGroupDraft != null)
                _FloatingDetailGroupDrawer(
                  draft: state.detailGroupDraft!,
                  snapshot: state.detailManagement!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
              if (state.floatingDetailDraft != null)
                _FloatingDetailDrawer(
                  draft: state.floatingDetailDraft!,
                  snapshot: state.detailManagement!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
              if (state.fiscalYearDraft != null)
                _FiscalYearDrawer(
                  draft: state.fiscalYearDraft!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
              if (state.fiscalPeriodDraft != null)
                _FiscalPeriodDrawer(
                  draft: state.fiscalPeriodDraft!,
                  financial: state.financial!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
              if (state.periodLockDraft != null)
                _PeriodLockDrawer(
                  draft: state.periodLockDraft!,
                  financial: state.financial!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
              if (state.periodUnlockDraft != null)
                _PeriodUnlockDrawer(
                  draft: state.periodUnlockDraft!,
                  saving: state.phase == OrganizationPhase.saving,
                ),
            ],
          );
        },
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final OrganizationSettingsState state;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (state.view) {
                            SettingsView.dashboard => 'داشبورد تنظیمات',
                            SettingsView.structure => 'ساختار سازمانی',
                            SettingsView.financial => 'تنظیمات مالی',
                          },
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'پیکربندی سازمان، شرکت، شعبه و حسابداری',
                          style: TextStyle(color: AsoudColors.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _chooseKind(context),
                    icon: const Icon(Icons.add),
                    label: const Text('واحد سازمانی جدید'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<SettingsView>(
                segments: const [
                  ButtonSegment(
                    value: SettingsView.dashboard,
                    label: Text('داشبورد تنظیمات'),
                    icon: Icon(Icons.dashboard_outlined),
                  ),
                  ButtonSegment(
                    value: SettingsView.structure,
                    label: Text('ساختار سازمانی'),
                    icon: Icon(Icons.account_tree_outlined),
                  ),
                  ButtonSegment(
                    value: SettingsView.financial,
                    label: Text('تنظیمات مالی'),
                    icon: Icon(Icons.receipt_long_outlined),
                  ),
                ],
                selected: {state.view},
                onSelectionChanged: (value) =>
                    context.read<OrganizationSettingsCubit>().show(value.first),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );

  Future<void> _chooseKind(BuildContext context) async {
    final kind = await showDialog<OrganizationUnitKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('نوع واحد سازمانی'),
        children: [
          for (final item in const [
            (OrganizationUnitKind.holding, 'هلدینگ', Icons.hub_outlined),
            (OrganizationUnitKind.company, 'شرکت یا شخص', Icons.apartment),
            (OrganizationUnitKind.branch, 'شعبه', Icons.store_outlined),
          ])
            ListTile(
              leading: Icon(item.$3),
              title: Text(item.$2),
              onTap: () => Navigator.pop(context, item.$1),
            ),
        ],
      ),
    );
    if (kind != null && context.mounted) {
      context.read<OrganizationSettingsCubit>().start(kind);
    }
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard(this.snapshot, {required this.onOpenDestination});
  final OrganizationSnapshot snapshot;
  final ValueChanged<String>? onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('هلدینگ‌ها', snapshot.holdings.length, Icons.hub_outlined),
      ('شرکت‌ها', snapshot.companies.length, Icons.apartment_outlined),
      ('شعب عملیاتی', snapshot.branches.length, Icons.store_outlined),
      ('وضعیت کنترل', 1, Icons.verified_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200
                ? 4
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(child: Icon(card.$3)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(card.$1),
                                Text(
                                  card.$2.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SettingsCards(onOpenDestination: onOpenDestination),
      ],
    );
  }
}

class _SettingsCards extends StatelessWidget {
  const _SettingsCards({required this.onOpenDestination});
  final ValueChanged<String>? onOpenDestination;

  String _destination(IconData icon) {
    if (icon == Icons.tag) return 'document_sequences';
    if (icon == Icons.manage_accounts) return 'organization_access';
    if (icon == Icons.alt_route) return 'approval_settings';
    if (icon == Icons.flag_outlined) return 'iran_settings';
    if (icon == Icons.dataset_outlined) return 'master_data';
    if (icon == Icons.lock_outline) return 'control_locks';
    return 'settings_dashboard';
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in const [
            (
              'ساختار سازمانی',
              'هلدینگ، شرکت و شعبه',
              Icons.account_tree,
              'structure',
            ),
            (
              'مالی و دوره‌ها',
              'سال مالی و نمودار حساب‌ها',
              Icons.receipt_long,
              'financial',
            ),
            ('شماره‌گذاری', 'شماره موقت و قطعی', Icons.tag, null),
            (
              'کاربران و دسترسی',
              'دامنه Company/Branch',
              Icons.manage_accounts,
              null,
            ),
            ('گردش کار', 'مسیرها و تأییدها', Icons.alt_route, null),
            (
              'حسابداری ایران',
              'مالیات و خروجی قانونی',
              Icons.flag_outlined,
              null,
            ),
            (
              'اطلاعات پایه',
              'کالا، خدمت و طرف‌حساب',
              Icons.dataset_outlined,
              null,
            ),
            (
              'قفل و کنترل',
              'دوره و رویداد حسابرسی',
              Icons.lock_outline,
              null,
            ),
          ])
            SizedBox(
              width: 330,
              height: 142,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final destination = item.$4 ?? _destination(item.$3);
                    if (destination == 'structure') {
                      context
                          .read<OrganizationSettingsCubit>()
                          .show(SettingsView.structure);
                    } else if (destination == 'financial') {
                      context
                          .read<OrganizationSettingsCubit>()
                          .show(SettingsView.financial);
                    } else {
                      onOpenDestination?.call(destination);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(child: Icon(item.$3)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: AsoudColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'باز کردن تنظیمات',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_left,
                          size: 18,
                          color: AsoudColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _Structure extends StatelessWidget {
  const _Structure(this.snapshot);
  final OrganizationSnapshot snapshot;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final holding in snapshot.holdings)
            Card(
              child: ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.hub_outlined)),
                title: Text(holding.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('هلدینگ • ${holding.code ?? ''}'),
                children: [
                  for (final company in snapshot.companies.where(
                    (item) => item.parent == holding.name,
                  ))
                    ExpansionTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: Text(company.title),
                      subtitle: const Text('Company مستقل'),
                      children: [
                        for (final branch in snapshot.branches.where(
                          (item) => item.parent == company.name,
                        ))
                          ListTile(
                            leading: const Icon(Icons.store_outlined),
                            title: Text(branch.title),
                            subtitle: const Text(
                              'Branch • حسابداری ارث‌بری‌شده از شرکت',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      );
}

class _FinancialSettings extends StatelessWidget {
  const _FinancialSettings(this.state);

  final OrganizationSettingsState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.financial;
    final draft = state.financialDraft;
    if (settings == null || draft == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _FinancialSectionSelector(selected: state.financialSection),
        const SizedBox(height: 16),
        if (state.financialSection == FinancialSection.general) ...[
          _FinancialStatus(settings: settings),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تنظیمات عمومی حسابداری',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'این تنظیمات در سطح شرکت فعال ذخیره می‌شوند و روی دفاتر سایر شرکت‌ها اثری ندارند.',
                    style: TextStyle(color: AsoudColors.muted),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 900
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: width,
                            child: _ReadOnlyField(
                              'شرکت فعال',
                              settings.companyName.isEmpty
                                  ? settings.company
                                  : settings.companyName,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: const _ReadOnlyField(
                              'ارز دفتر کل',
                              'ریال ایران (IRR)',
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<String>(
                              value: draft.coaTemplate.isEmpty
                                  ? null
                                  : draft.coaTemplate,
                              decoration: const InputDecoration(
                                labelText: 'الگوی نمودار حساب‌ها *',
                              ),
                              items: [
                                for (final template in settings.templates)
                                  DropdownMenuItem(
                                    value: template['name']?.toString(),
                                    child: Text(
                                      '${template['template_title'] ?? template['name']}'
                                      ' — نسخه ${template['version'] ?? '-'}',
                                    ),
                                  ),
                              ],
                              onChanged: (value) => context
                                  .read<OrganizationSettingsCubit>()
                                  .updateFinancial(coaTemplate: value ?? ''),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<String>(
                              value: draft.amountInputUnit,
                              decoration: const InputDecoration(
                                labelText: 'واحد ورود مبلغ',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'IRR',
                                  child: Text('ریال'),
                                ),
                                DropdownMenuItem(
                                  value: 'TOMAN',
                                  child:
                                      Text('تومان؛ ذخیره در دفتر کل به ریال'),
                                ),
                              ],
                              onChanged: (value) => context
                                  .read<OrganizationSettingsCubit>()
                                  .updateFinancial(amountInputUnit: value),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<String>(
                              value: draft.calendarDisplay,
                              decoration: const InputDecoration(
                                labelText: 'نمایش تقویم',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Jalali',
                                  child: Text('شمسی'),
                                ),
                                DropdownMenuItem(
                                  value: 'Gregorian',
                                  child: Text('میلادی'),
                                ),
                              ],
                              onChanged: (value) => context
                                  .read<OrganizationSettingsCubit>()
                                  .updateFinancial(calendarDisplay: value),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _ReadOnlyField(
                              'منطقه زمانی',
                              settings.timezone,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: state.phase == OrganizationPhase.saving
                          ? null
                          : context
                              .read<OrganizationSettingsCubit>()
                              .saveFinancial,
                      icon: state.phase == OrganizationPhase.saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('ذخیره تنظیمات مالی'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 1200
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _FiscalYearsCard(rows: settings.fiscalYears),
                  ),
                  SizedBox(
                    width: width,
                    child: _FiscalPeriodsCard(rows: settings.fiscalPeriods),
                  ),
                  SizedBox(
                    width: width,
                    child: _PeriodLocksCard(rows: settings.periodLocks),
                  ),
                ],
              );
            },
          ),
        ],
        if (state.financialSection == FinancialSection.chartOfAccounts)
          _ChartOfAccountsPanel(snapshot: state.accountRules),
        if (state.financialSection == FinancialSection.floatingDetails)
          _FloatingDetailsPanel(snapshot: state.detailManagement),
        if (state.financialSection == FinancialSection.defaultAccounts)
          _DefaultAccountsPanel(
            settings: settings,
            draft: draft,
            saving: state.phase == OrganizationPhase.saving,
          ),
        if (state.financialSection == FinancialSection.periodsControls)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 1200
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _FiscalYearsCard(rows: settings.fiscalYears),
                  ),
                  SizedBox(
                    width: width,
                    child: _FiscalPeriodsCard(rows: settings.fiscalPeriods),
                  ),
                  SizedBox(
                    width: width,
                    child: _PeriodLocksCard(rows: settings.periodLocks),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _FinancialSectionSelector extends StatelessWidget {
  const _FinancialSectionSelector({required this.selected});

  final FinancialSection selected;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: SegmentedButton<FinancialSection>(
          segments: const [
            ButtonSegment(
              value: FinancialSection.general,
              label: Text('عمومی'),
              icon: Icon(Icons.tune),
            ),
            ButtonSegment(
              value: FinancialSection.periodsControls,
              label: Text('سال، دوره و قفل'),
              icon: Icon(Icons.lock_clock_outlined),
            ),
            ButtonSegment(
              value: FinancialSection.defaultAccounts,
              label: Text('حساب‌های پیش‌فرض'),
              icon: Icon(Icons.rule_folder_outlined),
            ),
            ButtonSegment(
              value: FinancialSection.chartOfAccounts,
              label: Text('نمودار حساب‌ها'),
              icon: Icon(Icons.account_tree_outlined),
            ),
            ButtonSegment(
              value: FinancialSection.floatingDetails,
              label: Text('تفصیلی‌های شناور'),
              icon: Icon(Icons.badge_outlined),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (value) => context
              .read<OrganizationSettingsCubit>()
              .showFinancialSection(value.first),
        ),
      );
}

class _DefaultAccountsPanel extends StatelessWidget {
  const _DefaultAccountsPanel({
    required this.settings,
    required this.draft,
    required this.saving,
  });

  final FinancialSettingsSnapshot settings;
  final FinancialSettingsDraft draft;
  final bool saving;

  List<Map<String, dynamic>> _accounts(String expected) =>
      settings.accountOptions
          .where((row) =>
              row['account_type']?.toString() == expected ||
              row['root_type']?.toString() == expected)
          .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'حساب‌های پیش‌فرض شرکت',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'این حساب‌ها هنگام ایجاد طرف‌حساب، کالا و اسناد عملیاتی شرکت فعال استفاده می‌شوند.',
              style: TextStyle(color: AsoudColors.muted),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب دریافتنی',
                        value: draft.defaultReceivableAccount,
                        rows: _accounts('Receivable'),
                        changed: (value) => cubit.updateFinancial(
                            defaultReceivableAccount: value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب پرداختنی',
                        value: draft.defaultPayableAccount,
                        rows: _accounts('Payable'),
                        changed: (value) =>
                            cubit.updateFinancial(defaultPayableAccount: value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب درآمد',
                        value: draft.defaultIncomeAccount,
                        rows: _accounts('Income'),
                        changed: (value) =>
                            cubit.updateFinancial(defaultIncomeAccount: value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب هزینه',
                        value: draft.defaultExpenseAccount,
                        rows: _accounts('Expense'),
                        changed: (value) =>
                            cubit.updateFinancial(defaultExpenseAccount: value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب صندوق',
                        value: draft.defaultCashAccount,
                        rows: _accounts('Cash'),
                        changed: (value) =>
                            cubit.updateFinancial(defaultCashAccount: value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب بانک',
                        value: draft.defaultBankAccount,
                        rows: _accounts('Bank'),
                        changed: (value) =>
                            cubit.updateFinancial(defaultBankAccount: value),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DefaultAccountSelect(
                        label: 'حساب تعدیلات موجودی',
                        value: draft.stockAdjustmentAccount,
                        rows: _accounts('Expense'),
                        changed: (value) => cubit.updateFinancial(
                            stockAdjustmentAccount: value),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: saving ? null : cubit.saveFinancial,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('ذخیره حساب‌های پیش‌فرض'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultAccountSelect extends StatelessWidget {
  const _DefaultAccountSelect({
    required this.label,
    required this.value,
    required this.rows,
    required this.changed,
  });

  final String label;
  final String value;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<String> changed;

  @override
  Widget build(BuildContext context) {
    final names = {
      if (value.isNotEmpty) value,
      ...rows.map((row) => row['name']?.toString() ?? '').where(
            (name) => name.isNotEmpty,
          ),
    };
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('انتخاب نشده')),
        for (final name in names)
          DropdownMenuItem(value: name, child: Text(name)),
      ],
      onChanged: (item) => changed(item ?? ''),
    );
  }
}

class _ChartOfAccountsPanel extends StatelessWidget {
  const _ChartOfAccountsPanel({required this.snapshot});

  final AccountRulesSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نمودار حساب‌ها',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Text(
                        'حساب‌های شرکت فعال و قواعد تفصیلی هر حساب سندپذیر',
                        style: TextStyle(color: AsoudColors.muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      context.read<OrganizationSettingsCubit>().startAccount,
                  icon: const Icon(Icons.add),
                  label: const Text('حساب جدید'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data.accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('حسابی تعریف نشده است.')),
              )
            else
              Column(
                children: [
                  for (final entry in _accountTreeEntries(data.accounts))
                    _AccountTreeRow(
                      entry: entry,
                      ruleCount: data.rules[entry.account.name]
                              ?.where((rule) => rule.enabled)
                              .length ??
                          0,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountTreeEntry {
  const _AccountTreeEntry(this.account, this.depth);

  final ChartAccount account;
  final int depth;
}

List<_AccountTreeEntry> _accountTreeEntries(List<ChartAccount> accounts) {
  final accountNames = accounts.map((account) => account.name).toSet();
  final children = <String, List<ChartAccount>>{};
  for (final account in accounts) {
    children.putIfAbsent(account.parentAccount, () => []).add(account);
  }
  for (final rows in children.values) {
    rows.sort(
        (first, second) => first.accountNumber.compareTo(second.accountNumber));
  }

  final entries = <_AccountTreeEntry>[];
  final visited = <String>{};
  void addBranch(ChartAccount account, int depth) {
    if (!visited.add(account.name)) return;
    entries.add(_AccountTreeEntry(account, depth));
    for (final child in children[account.name] ?? const <ChartAccount>[]) {
      addBranch(child, depth + 1);
    }
  }

  final roots = accounts
      .where((account) =>
          account.parentAccount.isEmpty ||
          !accountNames.contains(account.parentAccount))
      .toList()
    ..sort(
        (first, second) => first.accountNumber.compareTo(second.accountNumber));
  for (final root in roots) {
    addBranch(root, 0);
  }
  for (final account in accounts) {
    addBranch(account, 0);
  }
  return entries;
}

class _AccountTreeRow extends StatelessWidget {
  const _AccountTreeRow({
    required this.entry,
    required this.ruleCount,
  });

  final _AccountTreeEntry entry;
  final int ruleCount;

  @override
  Widget build(BuildContext context) {
    final account = entry.account;
    final cubit = context.read<OrganizationSettingsCubit>();
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: entry.depth * 28,
        bottom: 8,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        color: entry.depth == 0 ? const Color(0xfff8fafd) : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => cubit.startAccount(account),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  account.isGroup
                      ? Icons.account_tree_outlined
                      : Icons.description_outlined,
                  color: account.isGroup ? AsoudColors.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account.accountNumber} — ${account.accountName}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        account.parentAccount.isEmpty
                            ? 'ریشه نمودار حساب‌ها'
                            : 'والد: ${account.parentAccount}',
                        style: const TextStyle(
                          color: AsoudColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(_accountLevelLabel(account.accountLevel))),
                if (!account.isGroup) ...[
                  const SizedBox(width: 8),
                  Chip(label: Text('$ruleCount گروه تفصیلی')),
                ],
                const SizedBox(width: 8),
                if (account.isGroup)
                  IconButton(
                    tooltip: 'ایجاد حساب زیرمجموعه',
                    onPressed: () => cubit.startChildAccount(account),
                    icon: const Icon(Icons.subdirectory_arrow_left),
                  ),
                IconButton(
                  tooltip: 'ایجاد حساب هم‌سطح',
                  onPressed: account.parentAccount.isEmpty
                      ? null
                      : () => cubit.startSiblingAccount(account),
                  icon: const Icon(Icons.add_link_outlined),
                ),
                IconButton(
                  tooltip: 'ویرایش حساب',
                  onPressed: () => cubit.startAccount(account),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _accountLevelLabel(String value) => switch (value) {
      'Group' => 'گروه',
      'Ledger' => 'کل',
      'Subsidiary' => 'معین',
      _ => 'نامشخص',
    };

String _detailTypeLabel(String value) => switch (value) {
      'Customer' => 'مشتری',
      'Supplier' => 'تأمین‌کننده',
      'Employee' => 'کارمند',
      'Bank' => 'بانک',
      'Cashbox' => 'صندوق',
      'Project' => 'پروژه',
      'Cost Center' => 'مرکز هزینه',
      'Branch' => 'شعبه',
      _ => 'سایر',
    };

class _FinancialStatus extends StatelessWidget {
  const _FinancialStatus({required this.settings});

  final FinancialSettingsSnapshot settings;

  @override
  Widget build(BuildContext context) {
    final completed = settings.setupStatus == 'Completed';
    return Card(
      color: completed ? const Color(0xffecfdf3) : const Color(0xfffff8e8),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  completed ? const Color(0xffd1fadf) : const Color(0xffffedc2),
              child: Icon(
                completed ? Icons.verified_outlined : Icons.pending_actions,
                color: completed
                    ? const Color(0xff067647)
                    : const Color(0xffb54708),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completed
                        ? 'پایه حسابداری ایران فعال است'
                        : 'راه‌اندازی حسابداری ایران تکمیل نشده است',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    completed
                        ? 'تنظیمات این شرکت مستقل و آماده استفاده عملیاتی است.'
                        : 'الگوی حساب‌ها را انتخاب و تنظیمات را ذخیره کنید.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiscalYearsCard extends StatelessWidget {
  const _FiscalYearsCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.calendar_month)),
                title: const Text(
                  'سال‌های مالی',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('سال‌های قابل استفاده برای شرکت فعال'),
                trailing: IconButton.filled(
                  tooltip: 'سال مالی جدید',
                  onPressed:
                      context.read<OrganizationSettingsCubit>().startFiscalYear,
                  icon: const Icon(Icons.add),
                ),
              ),
              if (rows.isEmpty)
                const Text('سال مالی تعریف نشده است.')
              else
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['name']?.toString() ?? '-'),
                    subtitle: Text(
                      '${row['year_start_date'] ?? '-'} تا '
                      '${row['year_end_date'] ?? '-'}',
                    ),
                    trailing: IconButton(
                      tooltip: row['is_global'] == true
                          ? 'سال مالی عمومی از این صفحه ویرایش نمی‌شود'
                          : 'ویرایش',
                      onPressed: row['is_global'] == true
                          ? null
                          : () => context
                              .read<OrganizationSettingsCubit>()
                              .startFiscalYear(row),
                      icon: Icon(
                        row['is_global'] == true
                            ? Icons.public
                            : Icons.edit_outlined,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _FiscalPeriodsCard extends StatelessWidget {
  const _FiscalPeriodsCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const CircleAvatar(child: Icon(Icons.date_range_outlined)),
                title: const Text(
                  'دوره‌های مالی',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('بازه‌های استاندارد یا تعدیلاتی'),
                trailing: IconButton.filled(
                  tooltip: 'دوره مالی جدید',
                  onPressed: context
                      .read<OrganizationSettingsCubit>()
                      .startFiscalPeriod,
                  icon: const Icon(Icons.add),
                ),
              ),
              if (rows.isEmpty)
                const Text('دوره مالی تعریف نشده است.')
              else
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['period_name']?.toString() ?? '-'),
                    subtitle: Text(
                      '${row['from_date'] ?? '-'} تا ${row['to_date'] ?? '-'}',
                    ),
                    onTap: () => context
                        .read<OrganizationSettingsCubit>()
                        .startFiscalPeriod(row),
                    trailing: IconButton(
                      tooltip: 'قفل این دوره',
                      onPressed: row['enabled'] == 1 || row['enabled'] == true
                          ? () => context
                              .read<OrganizationSettingsCubit>()
                              .startPeriodLock(row)
                          : null,
                      icon: const Icon(Icons.lock_outline),
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _PeriodLocksCard extends StatelessWidget {
  const _PeriodLocksCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.lock_outline)),
                title: const Text(
                  'قفل‌های دوره',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('قفل و بازگشایی کنترل‌شده'),
                trailing: IconButton.filled(
                  tooltip: 'قفل بازه جدید',
                  onPressed:
                      context.read<OrganizationSettingsCubit>().startPeriodLock,
                  icon: const Icon(Icons.lock),
                ),
              ),
              if (rows.isEmpty)
                const Text('هیچ دوره‌ای قفل نشده است.')
              else
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['fiscal_year']?.toString() ?? '-'),
                    subtitle: Text(
                      '${row['from_date'] ?? '-'} تا ${row['to_date'] ?? '-'}',
                    ),
                    trailing: row['docstatus'] == 1
                        ? IconButton(
                            tooltip: 'بازگشایی کنترل‌شده',
                            onPressed: () => context
                                .read<OrganizationSettingsCubit>()
                                .startPeriodUnlock(
                                  row['name']?.toString() ?? '',
                                ),
                            icon: const Icon(Icons.lock_open_outlined),
                          )
                        : const Chip(label: Text('بازگشایی‌شده')),
                  ),
            ],
          ),
        ),
      );
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 330,
        child: TextFormField(
          initialValue: value,
          readOnly: true,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _FiscalYearDrawer extends StatelessWidget {
  const _FiscalYearDrawer({required this.draft, required this.saving});
  final FiscalYearDraft draft;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    return _SettingsDrawer(
      title: draft.name.isEmpty ? 'ایجاد سال مالی' : 'ویرایش سال مالی',
      onClose: cubit.cancelFiscalYear,
      onSave: saving ? null : cubit.saveFiscalYear,
      saving: saving,
      children: [
        TextFormField(
          key: ValueKey('year-${draft.name}'),
          initialValue: draft.yearName,
          readOnly: draft.name.isNotEmpty,
          decoration: const InputDecoration(
            labelText: 'نام سال مالی *',
            hintText: 'مثلاً ۱۴۰۶',
          ),
          onChanged: (value) => cubit.updateFiscalYear(yearName: value),
        ),
        TextFormField(
          key: ValueKey('year-from-${draft.name}'),
          initialValue: draft.fromDate,
          decoration: const InputDecoration(
            labelText: 'تاریخ شروع *',
            hintText: 'YYYY-MM-DD',
          ),
          onChanged: (value) => cubit.updateFiscalYear(fromDate: value),
        ),
        TextFormField(
          key: ValueKey('year-to-${draft.name}'),
          initialValue: draft.toDate,
          decoration: const InputDecoration(
            labelText: 'تاریخ پایان *',
            hintText: 'YYYY-MM-DD',
          ),
          onChanged: (value) => cubit.updateFiscalYear(toDate: value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: draft.disabled,
          title: const Text('سال مالی غیرفعال باشد'),
          onChanged: (value) => cubit.updateFiscalYear(disabled: value),
        ),
        const Card(
          color: Color(0xffeff6ff),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'سال مالی جدید فقط به Company فعال اختصاص می‌یابد. سال مالی عمومی از این فرم قابل ویرایش نیست.',
            ),
          ),
        ),
      ],
    );
  }
}

class _FiscalPeriodDrawer extends StatelessWidget {
  const _FiscalPeriodDrawer({
    required this.draft,
    required this.financial,
    required this.saving,
  });
  final FiscalPeriodDraft draft;
  final FinancialSettingsSnapshot financial;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    return _SettingsDrawer(
      title: draft.name.isEmpty ? 'ایجاد دوره مالی' : 'ویرایش دوره مالی',
      onClose: cubit.cancelFiscalPeriod,
      onSave: saving ? null : cubit.saveFiscalPeriod,
      saving: saving,
      children: [
        DropdownButtonFormField<String>(
          value: draft.fiscalYear.isEmpty ? null : draft.fiscalYear,
          decoration: const InputDecoration(labelText: 'سال مالی *'),
          items: [
            for (final year in financial.fiscalYears)
              DropdownMenuItem(
                value: year['name']?.toString(),
                child: Text(year['name']?.toString() ?? '-'),
              ),
          ],
          onChanged: (value) =>
              cubit.updateFiscalPeriod(fiscalYear: value ?? ''),
        ),
        TextFormField(
          key: ValueKey('period-name-${draft.name}'),
          initialValue: draft.periodName,
          decoration: const InputDecoration(labelText: 'عنوان دوره *'),
          onChanged: (value) => cubit.updateFiscalPeriod(periodName: value),
        ),
        DropdownButtonFormField<String>(
          value: draft.periodType,
          decoration: const InputDecoration(labelText: 'نوع دوره'),
          items: const [
            DropdownMenuItem(value: 'Standard', child: Text('استاندارد')),
            DropdownMenuItem(value: 'Adjustment', child: Text('تعدیلاتی')),
          ],
          onChanged: (value) => cubit.updateFiscalPeriod(periodType: value),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: draft.fromDate,
                decoration: const InputDecoration(
                  labelText: 'از تاریخ *',
                  hintText: 'YYYY-MM-DD',
                ),
                onChanged: (value) => cubit.updateFiscalPeriod(fromDate: value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.toDate,
                decoration: const InputDecoration(
                  labelText: 'تا تاریخ *',
                  hintText: 'YYYY-MM-DD',
                ),
                onChanged: (value) => cubit.updateFiscalPeriod(toDate: value),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: draft.enabled,
          title: const Text('دوره فعال باشد'),
          onChanged: (value) => cubit.updateFiscalPeriod(enabled: value),
        ),
      ],
    );
  }
}

class _PeriodLockDrawer extends StatelessWidget {
  const _PeriodLockDrawer({
    required this.draft,
    required this.financial,
    required this.saving,
  });
  final PeriodLockDraft draft;
  final FinancialSettingsSnapshot financial;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    final activePeriods = financial.fiscalPeriods
        .where((row) => row['enabled'] == 1 || row['enabled'] == true)
        .toList(growable: false);
    return _SettingsDrawer(
      title: 'قفل دوره مالی',
      onClose: cubit.cancelPeriodLock,
      onSave: saving ? null : cubit.savePeriodLock,
      saving: saving,
      children: [
        DropdownButtonFormField<String>(
          value: draft.fiscalPeriod.isEmpty ? '' : draft.fiscalPeriod,
          decoration: const InputDecoration(labelText: 'دوره مالی'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('بازه انتخابی بدون دوره مشخص'),
            ),
            for (final period in activePeriods)
              DropdownMenuItem(
                value: period['name']?.toString(),
                child: Text(period['period_name']?.toString() ?? '-'),
              ),
          ],
          onChanged: (value) =>
              cubit.updatePeriodLock(fiscalPeriod: value ?? ''),
        ),
        DropdownButtonFormField<String>(
          value: draft.fiscalYear.isEmpty ? null : draft.fiscalYear,
          decoration: const InputDecoration(labelText: 'سال مالی *'),
          items: [
            for (final year in financial.fiscalYears)
              DropdownMenuItem(
                value: year['name']?.toString(),
                child: Text(year['name']?.toString() ?? '-'),
              ),
          ],
          onChanged: draft.fiscalPeriod.isNotEmpty
              ? null
              : (value) => cubit.updatePeriodLock(fiscalYear: value ?? ''),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('lock-from-${draft.fiscalPeriod}'),
                initialValue: draft.fromDate,
                readOnly: draft.fiscalPeriod.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'از تاریخ *',
                  hintText: 'YYYY-MM-DD',
                ),
                onChanged: (value) => cubit.updatePeriodLock(fromDate: value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey('lock-to-${draft.fiscalPeriod}'),
                initialValue: draft.toDate,
                readOnly: draft.fiscalPeriod.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'تا تاریخ *',
                  hintText: 'YYYY-MM-DD',
                ),
                onChanged: (value) => cubit.updatePeriodLock(toDate: value),
              ),
            ),
          ],
        ),
        TextFormField(
          initialValue: draft.reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'دلیل قفل *'),
          onChanged: (value) => cubit.updatePeriodLock(reason: value),
        ),
        const Card(
          color: Color(0xfffff8e8),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'قبل از قفل باید همه اسناد ثبت‌شده این بازه شماره قطعی داشته باشند. پس از قفل، ثبت، اصلاح و ابطال سند در بازه ممنوع است.',
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodUnlockDrawer extends StatelessWidget {
  const _PeriodUnlockDrawer({required this.draft, required this.saving});
  final PeriodUnlockDraft draft;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    return _SettingsDrawer(
      title: 'بازگشایی کنترل‌شده دوره',
      onClose: cubit.cancelPeriodUnlock,
      onSave: saving ? null : cubit.savePeriodUnlock,
      saving: saving,
      children: [
        TextFormField(
          initialValue: draft.lockName,
          readOnly: true,
          decoration: const InputDecoration(labelText: 'شناسه قفل'),
        ),
        TextFormField(
          initialValue: draft.reason,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'دلیل بازگشایی *'),
          onChanged: cubit.updatePeriodUnlock,
        ),
        const Card(
          color: Color(0xfffff1f2),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'بازگشایی در زنجیره حسابرسی ثبت می‌شود. اسناد قفل‌شده به وضعیت شماره قطعی بازمی‌گردند، اما شماره قطعی آن‌ها حذف یا تغییر نمی‌کند.',
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountFormDrawer extends StatelessWidget {
  const _AccountFormDrawer({
    required this.draft,
    required this.snapshot,
    required this.saving,
  });

  final ChartAccountDraft draft;
  final AccountRulesSnapshot snapshot;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    final parents = snapshot.accounts
        .where((account) => account.isGroup && account.name != draft.name)
        .toList(growable: false);
    final parentValue = parents.any((row) => row.name == draft.parentAccount)
        ? draft.parentAccount
        : null;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black38,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
            elevation: 18,
            color: Colors.white,
            child: SizedBox(
              width: 780,
              height: double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.name.isEmpty
                                    ? 'ایجاد حساب'
                                    : 'ویرایش حساب',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const Text(
                                'یک فرم برای ایجاد حساب گروه، کل یا معین',
                                style: TextStyle(color: AsoudColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: cubit.cancelAccount,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'جایگاه و شناسه حساب',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: draft.accountLevel,
                          decoration: const InputDecoration(
                            labelText: 'سطح حساب *',
                            helperText:
                                'گروه و کل غیرسندپذیر هستند؛ معین سندپذیر است',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Group',
                              child: Text('گروه'),
                            ),
                            DropdownMenuItem(
                              value: 'Ledger',
                              child: Text('کل'),
                            ),
                            DropdownMenuItem(
                              value: 'Subsidiary',
                              child: Text('معین'),
                            ),
                          ],
                          onChanged: (value) =>
                              cubit.updateAccount(accountLevel: value),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: parentValue,
                          decoration:
                              const InputDecoration(labelText: 'حساب والد *'),
                          items: [
                            for (final account in parents)
                              DropdownMenuItem(
                                value: account.name,
                                child: Text(
                                    '${account.accountNumber} — ${account.accountName}'),
                              ),
                          ],
                          onChanged: (value) =>
                              cubit.updateAccount(parentAccount: value ?? ''),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('number-${draft.name}'),
                                initialValue: draft.accountNumber,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'کد حساب *',
                                  helperText: 'فقط رقم و یکتا در شرکت',
                                ),
                                onChanged: (value) =>
                                    cubit.updateAccount(accountNumber: value),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('title-${draft.name}'),
                                initialValue: draft.accountName,
                                decoration: const InputDecoration(
                                    labelText: 'عنوان حساب *'),
                                onChanged: (value) =>
                                    cubit.updateAccount(accountName: value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('type-${draft.name}'),
                                initialValue: draft.accountType,
                                decoration: const InputDecoration(
                                  labelText: 'نوع حساب',
                                  hintText:
                                      'Receivable, Payable, Cash, Expense Account',
                                ),
                                onChanged: (value) =>
                                    cubit.updateAccount(accountType: value),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('غیرفعال'),
                          subtitle: const Text(
                              'حساب غیرفعال برای ثبت سند جدید قابل انتخاب نیست'),
                          value: draft.disabled,
                          onChanged: (value) =>
                              cubit.updateAccount(disabled: value),
                        ),
                        const Divider(height: 36),
                        Text(
                          'گروه‌های تفصیلی مجاز',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        if (draft.accountLevel != 'Subsidiary')
                          const Card(
                            color: Color(0xfffff8e8),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'حساب گروه و کل مستقیماً سند نمی‌پذیرند؛ گروه‌های تفصیلی فقط برای حساب‌های معین قابل انتخاب هستند.',
                              ),
                            ),
                          )
                        else if (snapshot.detailGroups.isEmpty)
                          const Card(
                            color: Color(0xfff8fafd),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'هنوز گروه تفصیلی فعالی تعریف نشده است. ابتدا از بخش مدیریت تفصیلی شناور، گروه‌ها را ایجاد کنید.',
                              ),
                            ),
                          )
                        else
                          Card(
                            color: const Color(0xfff8fafd),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns =
                                      constraints.maxWidth >= 720;
                                  final itemWidth = twoColumns
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    children: [
                                      for (final group in snapshot.detailGroups)
                                        SizedBox(
                                          width: itemWidth,
                                          child: Card(
                                            margin: EdgeInsets.zero,
                                            child: CheckboxListTile(
                                              value: draft.rules.any(
                                                (rule) =>
                                                    rule.detailGroup ==
                                                        group.name &&
                                                    rule.enabled,
                                              ),
                                              enabled: group.enabled,
                                              title: Text(group.title),
                                              subtitle: Text(
                                                '${group.code} · ${_detailTypeLabel(group.detailType)}'
                                                '${group.enabled ? '' : ' · غیرفعال'}',
                                              ),
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                              onChanged: (value) => cubit
                                                  .toggleAccountDetailGroup(
                                                group,
                                                value ?? false,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: saving ? null : cubit.cancelAccount,
                          child: const Text('انصراف'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: saving ? null : cubit.saveChartAccount,
                          icon: saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('ذخیره حساب'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingDetailsPanel extends StatelessWidget {
  const _FloatingDetailsPanel({required this.snapshot});
  final FloatingDetailManagementSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) return const Center(child: CircularProgressIndicator());
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 900
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: width,
            child: _DetailListCard(
              title: 'گروه‌های تفصیلی',
              actionLabel: 'گروه جدید',
              onAdd: () =>
                  context.read<OrganizationSettingsCubit>().startDetailGroup(),
              children: [
                for (final group in data.groups)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.folder_outlined),
                    ),
                    title: Text(group.title),
                    subtitle: Text('${group.code} • ${group.detailType}'),
                    trailing: Icon(
                      group.enabled ? Icons.check_circle : Icons.block,
                      color: group.enabled ? Colors.green : Colors.grey,
                    ),
                    onTap: () => context
                        .read<OrganizationSettingsCubit>()
                        .startDetailGroup(group),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: width,
            child: _DetailListCard(
              title: 'تفصیلی‌های شرکت فعال',
              actionLabel: 'تفصیلی جدید',
              onAdd: data.groups.isEmpty
                  ? null
                  : () => context
                      .read<OrganizationSettingsCubit>()
                      .startFloatingDetail(),
              children: [
                for (final detail in data.details)
                  ListTile(
                    leading:
                        const CircleAvatar(child: Icon(Icons.badge_outlined)),
                    title: Text(detail.title),
                    subtitle: Text(
                      '${detail.code.isEmpty ? "بدون کد شرکت" : detail.code} • ${detail.detailType}',
                    ),
                    trailing: Icon(
                      detail.enabled && detail.companyEnabled
                          ? Icons.check_circle
                          : Icons.block,
                      color: detail.enabled && detail.companyEnabled
                          ? Colors.green
                          : Colors.grey,
                    ),
                    onTap: () => context
                        .read<OrganizationSettingsCubit>()
                        .startFloatingDetail(detail),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _DetailListCard extends StatelessWidget {
  const _DetailListCard({
    required this.title,
    required this.actionLabel,
    required this.onAdd,
    required this.children,
  });
  final String title;
  final String actionLabel;
  final VoidCallback? onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(actionLabel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (children.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'هنوز رکوردی ثبت نشده است.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...children,
            ],
          ),
        ),
      );
}

class _FloatingDetailGroupDrawer extends StatelessWidget {
  const _FloatingDetailGroupDrawer({
    required this.draft,
    required this.snapshot,
    required this.saving,
  });
  final FloatingDetailGroupDraft draft;
  final FloatingDetailManagementSnapshot snapshot;
  final bool saving;

  @override
  Widget build(BuildContext context) => _SettingsDrawer(
        title: draft.name.isEmpty ? 'ایجاد گروه تفصیلی' : 'ویرایش گروه تفصیلی',
        onClose: context.read<OrganizationSettingsCubit>().cancelDetailGroup,
        onSave: saving
            ? null
            : context.read<OrganizationSettingsCubit>().saveDetailGroup,
        saving: saving,
        children: [
          TextFormField(
            key: ValueKey('group-title-${draft.name}'),
            initialValue: draft.title,
            decoration: const InputDecoration(labelText: 'عنوان گروه *'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateDetailGroup(title: value),
          ),
          TextFormField(
            key: ValueKey('group-code-${draft.name}'),
            initialValue: draft.code,
            decoration: const InputDecoration(labelText: 'کد گروه *'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateDetailGroup(code: value),
          ),
          DropdownButtonFormField<String>(
            value: snapshot.detailTypes.contains(draft.detailType)
                ? draft.detailType
                : snapshot.detailTypes.isEmpty
                    ? null
                    : snapshot.detailTypes.first,
            decoration: const InputDecoration(labelText: 'نوع تفصیلی *'),
            items: [
              for (final type in snapshot.detailTypes)
                DropdownMenuItem(
                    value: type, child: Text(_detailTypeLabel(type))),
            ],
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateDetailGroup(detailType: value),
          ),
          DropdownButtonFormField<String>(
            value: draft.parentGroup.isEmpty ? '' : draft.parentGroup,
            decoration: const InputDecoration(labelText: 'گروه والد'),
            items: [
              const DropdownMenuItem(value: '', child: Text('بدون گروه والد')),
              for (final group in snapshot.groups.where(
                (value) =>
                    value.name != draft.name &&
                    value.detailType == draft.detailType,
              ))
                DropdownMenuItem(value: group.name, child: Text(group.title)),
            ],
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateDetailGroup(parentGroup: value ?? ''),
          ),
          SwitchListTile(
            value: draft.enabled,
            title: const Text('گروه فعال باشد'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateDetailGroup(enabled: value),
          ),
        ],
      );
}

class _FloatingDetailDrawer extends StatelessWidget {
  const _FloatingDetailDrawer({
    required this.draft,
    required this.snapshot,
    required this.saving,
  });
  final FloatingDetailDraft draft;
  final FloatingDetailManagementSnapshot snapshot;
  final bool saving;

  @override
  Widget build(BuildContext context) => _SettingsDrawer(
        title:
            draft.name.isEmpty ? 'ایجاد تفصیلی شناور' : 'ویرایش تفصیلی شناور',
        onClose: context.read<OrganizationSettingsCubit>().cancelFloatingDetail,
        onSave: saving
            ? null
            : context.read<OrganizationSettingsCubit>().saveFloatingDetail,
        saving: saving,
        children: [
          TextFormField(
            key: ValueKey('detail-title-${draft.name}'),
            initialValue: draft.title,
            decoration: const InputDecoration(labelText: 'عنوان تفصیلی *'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(title: value),
          ),
          DropdownButtonFormField<String>(
            value: draft.group.isEmpty ? null : draft.group,
            decoration: const InputDecoration(labelText: 'گروه تفصیلی *'),
            items: [
              for (final group
                  in snapshot.groups.where((value) => value.enabled))
                DropdownMenuItem(
                  value: group.name,
                  child: Text(
                      '${group.title} — ${_detailTypeLabel(group.detailType)}'),
                ),
            ],
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(group: value ?? ''),
          ),
          TextFormField(
            key: ValueKey('detail-code-${draft.name}'),
            initialValue: draft.code,
            decoration:
                const InputDecoration(labelText: 'کد تفصیلی در شرکت فعال *'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(code: value),
          ),
          TextFormField(
            key: ValueKey('reference-type-${draft.name}'),
            initialValue: draft.referenceDoctype,
            decoration: const InputDecoration(
              labelText: 'نوع مرجع (اختیاری)',
              hintText: 'Customer / Supplier / Employee',
            ),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(referenceDoctype: value),
          ),
          TextFormField(
            key: ValueKey('reference-name-${draft.name}'),
            initialValue: draft.referenceName,
            decoration:
                const InputDecoration(labelText: 'رکورد مرجع (اختیاری)'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(referenceName: value),
          ),
          SwitchListTile(
            value: draft.enabled,
            title: const Text('فعال در سطح هلدینگ'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(enabled: value),
          ),
          SwitchListTile(
            value: draft.companyEnabled,
            title: const Text('فعال در شرکت انتخاب‌شده'),
            onChanged: (value) => context
                .read<OrganizationSettingsCubit>()
                .updateFloatingDetail(companyEnabled: value),
          ),
        ],
      );
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.title,
    required this.onClose,
    required this.onSave,
    required this.saving,
    required this.children,
  });
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onSave;
  final bool saving;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black38,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              elevation: 16,
              child: SizedBox(
                width: 560,
                height: double.infinity,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                              onPressed: onClose,
                              icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemBuilder: (_, index) => children[index],
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemCount: children.length,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          OutlinedButton(
                              onPressed: onClose, child: const Text('انصراف')),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: onSave,
                            icon: saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('ذخیره'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _Wizard extends StatelessWidget {
  const _Wizard({required this.draft});
  final OrganizationDraft draft;

  int get totalSteps => switch (draft.kind) {
        OrganizationUnitKind.holding => 3,
        OrganizationUnitKind.company => 4,
        OrganizationUnitKind.branch => 4,
      };

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black38,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              elevation: 16,
              color: Colors.white,
              child: SizedBox(
                width: 620,
                height: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: context
                                .read<OrganizationSettingsCubit>()
                                .cancel,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: (draft.step + 1) / totalSteps,
                      ),
                      const SizedBox(height: 8),
                      Text('مرحله ${draft.step + 1} از $totalSteps'),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final field in _fields)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: TextFormField(
                                  key: ValueKey('${draft.step}-${field.$1}'),
                                  initialValue: draft.values[field.$1],
                                  onChanged: (value) => context
                                      .read<OrganizationSettingsCubit>()
                                      .update(field.$1, value),
                                  decoration:
                                      InputDecoration(labelText: field.$2),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (draft.step > 0)
                            OutlinedButton(
                              onPressed: context
                                  .read<OrganizationSettingsCubit>()
                                  .previous,
                              child: const Text('مرحله قبل'),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: draft.step + 1 == totalSteps
                                ? context.read<OrganizationSettingsCubit>().save
                                : context
                                    .read<OrganizationSettingsCubit>()
                                    .next,
                            child: Text(draft.step + 1 == totalSteps
                                ? 'ثبت نهایی'
                                : 'ثبت و ادامه'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  String get _title => switch (draft.kind) {
        OrganizationUnitKind.holding => 'ثبت هلدینگ',
        OrganizationUnitKind.company => 'ثبت شرکت یا شخص',
        OrganizationUnitKind.branch => 'ثبت شعبه',
      };

  List<(String, String)> get _fields {
    if (draft.kind == OrganizationUnitKind.holding) {
      return switch (draft.step) {
        0 => const [
            ('holding_name', 'نام هلدینگ *'),
            ('holding_code', 'کد هلدینگ *'),
            ('consolidation_currency', 'ارز گزارش تلفیقی'),
          ],
        1 => const [
            ('consolidation_method', 'روش تلفیق'),
            ('member_companies', 'شرکت‌های عضو'),
          ],
        _ => const [('review_note', 'توضیحات و بازبینی نهایی')],
      };
    }
    if (draft.kind == OrganizationUnitKind.branch) {
      return switch (draft.step) {
        0 => const [
            ('company', 'شرکت مادر *'),
            ('branch_name', 'نام شعبه *'),
            ('branch_code', 'کد شعبه *'),
          ],
        1 => const [
            ('default_warehouse', 'انبار پیش‌فرض'),
            ('default_cost_center', 'مرکز هزینه'),
          ],
        2 => const [
            ('manager', 'مدیر شعبه'),
            ('numbering_series', 'سری شماره‌گذاری'),
          ],
        _ => const [('review_note', 'توضیحات و بازبینی نهایی')],
      };
    }
    return switch (draft.step) {
      0 => const [
          ('entity_type', 'نوع شخصیت: Legal یا Natural *'),
          ('company_name', 'نام شرکت / نام کامل *'),
          ('abbr', 'کد اختصاری لاتین *'),
          ('first_name', 'نام شخص حقیقی'),
          ('last_name', 'نام خانوادگی شخص حقیقی'),
          ('birth_date', 'تاریخ تولد شخص حقیقی'),
          ('registration_number', 'شماره ثبت'),
          ('national_id', 'شناسه ملی / کد ملی'),
          ('economic_code', 'کد اقتصادی'),
          ('legal_type', 'نوع شرکت'),
          ('activity_type', 'نوع فعالیت'),
        ],
      1 => const [
          ('phone', 'موبایل یا تلفن'),
          ('email', 'ایمیل'),
          ('website', 'وب‌سایت'),
          ('province', 'استان'),
          ('city', 'شهر'),
          ('legal_address', 'نشانی قانونی'),
          ('postal_code', 'کدپستی'),
        ],
      2 => const [
          ('holding', 'هلدینگ مادر'),
          ('default_currency', 'ارز پایه'),
          ('fiscal_year', 'سال مالی'),
          ('chart_of_accounts', 'نمودار حساب‌ها'),
        ],
      _ => const [
          ('logo', 'مسیر لوگو'),
          ('review_note', 'توضیحات و بازبینی نهایی'),
        ],
    };
  }
}
