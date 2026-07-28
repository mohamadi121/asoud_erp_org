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
    super.key,
  });

  final WorkContext context;
  final OrganizationGateway gateway;
  final SettingsView initialView;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OrganizationSettingsCubit(
          gateway,
          this.context,
          initialView: initialView,
        )..load(),
        child: const _OrganizationSettingsView(),
      );
}

class _OrganizationSettingsView extends StatelessWidget {
  const _OrganizationSettingsView();

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
                      SettingsView.dashboard => _Dashboard(state.snapshot),
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
  const _Dashboard(this.snapshot);
  final OrganizationSnapshot snapshot;

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
        const _SettingsCards(),
      ],
    );
  }
}

class _SettingsCards extends StatelessWidget {
  const _SettingsCards();
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in const [
            ('ساختار سازمانی', 'هلدینگ، شرکت و شعبه', Icons.account_tree),
            ('مالی و دوره‌ها', 'سال مالی و نمودار حساب‌ها', Icons.receipt_long),
            ('شماره‌گذاری', 'شماره موقت و قطعی', Icons.tag),
            ('کاربران و دسترسی', 'دامنه Company/Branch', Icons.manage_accounts),
            ('گردش کار', 'مسیرها و تأییدها', Icons.alt_route),
            ('حسابداری ایران', 'مالیات و خروجی قانونی', Icons.flag_outlined),
            ('اطلاعات پایه', 'کالا، خدمت و طرف‌حساب', Icons.dataset_outlined),
            ('قفل و کنترل', 'دوره و رویداد حسابرسی', Icons.lock_outline),
          ])
            SizedBox(
              width: 330,
              height: 130,
              child: Card(
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
                            Text(item.$1,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(item.$2,
                                style: const TextStyle(
                                    color: AsoudColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
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
              final width = constraints.maxWidth >= 900
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
                    child: _PeriodLocksCard(rows: settings.periodLocks),
                  ),
                ],
              );
            },
          ),
        ],
        if (state.financialSection == FinancialSection.chartOfAccounts)
          _ChartOfAccountsPanel(snapshot: state.accountRules),
        if (state.financialSection == FinancialSection.dimensions)
          _AccountDimensionsPanel(snapshot: state.accountRules),
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
              value: FinancialSection.chartOfAccounts,
              label: Text('نمودار حساب‌ها'),
              icon: Icon(Icons.account_tree_outlined),
            ),
            ButtonSegment(
              value: FinancialSection.dimensions,
              label: Text('تفصیلی و ابعاد'),
              icon: Icon(Icons.hub_outlined),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (value) => context
              .read<OrganizationSettingsCubit>()
              .showFinancialSection(value.first),
        ),
      );
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('کد')),
                    DataColumn(label: Text('عنوان حساب')),
                    DataColumn(label: Text('حساب والد')),
                    DataColumn(label: Text('نوع')),
                    DataColumn(label: Text('قواعد تفصیلی')),
                    DataColumn(label: Text('عملیات')),
                  ],
                  rows: [
                    for (final account in data.accounts)
                      DataRow(cells: [
                        DataCell(Text(account.accountNumber)),
                        DataCell(Text(account.accountName)),
                        DataCell(Text(account.parentAccount)),
                        DataCell(Text(account.isGroup
                            ? 'گروه'
                            : account.accountType.isEmpty
                                ? 'سندپذیر'
                                : account.accountType)),
                        DataCell(Text(account.isGroup
                            ? '—'
                            : '${data.rules[account.name]?.where((rule) => rule.enabled).length ?? 0} قاعده')),
                        DataCell(IconButton(
                          tooltip: 'ویرایش',
                          onPressed: () => context
                              .read<OrganizationSettingsCubit>()
                              .startAccount(account),
                          icon: const Icon(Icons.edit_outlined),
                        )),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountDimensionsPanel extends StatelessWidget {
  const _AccountDimensionsPanel({required this.snapshot});

  final AccountRulesSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final mappedAccounts = data.accounts
        .where((account) =>
            (data.rules[account.name] ?? const []).any((rule) => rule.enabled))
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'قواعد نگاشت حساب و تفصیلی',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'این صفحه نمای تجمیعی قواعد است؛ ویرایش دقیق از فرم حساب انجام می‌شود.',
              style: TextStyle(color: AsoudColors.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricChip(
                  label: 'حساب‌های نگاشت‌شده',
                  value: '${mappedAccounts.length}',
                ),
                _MetricChip(
                  label: 'انواع تفصیلی',
                  value: '${data.detailTypes.length}',
                ),
                _MetricChip(
                  label: 'قواعد فعال',
                  value:
                      '${data.rules.values.expand((rows) => rows).where((rule) => rule.enabled).length}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final account in mappedAccounts)
              Card(
                color: const Color(0xfff8fafd),
                child: ListTile(
                  title: Text(
                    '${account.accountNumber} — ${account.accountName}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      for (final rule in data.rules[account.name]!
                          .where((rule) => rule.enabled))
                        Chip(
                          label: Text(
                            '${_detailTypeLabel(rule.detailType)}'
                            '${rule.required ? ' • اجباری' : ''}',
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'ویرایش قواعد',
                    onPressed: () => context
                        .read<OrganizationSettingsCubit>()
                        .startAccount(account),
                    icon: const Icon(Icons.rule_folder_outlined),
                  ),
                ),
              ),
            if (mappedAccounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('هنوز قاعده تفصیلی فعالی تعریف نشده است.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: CircleAvatar(child: Text(value)),
        label: Text(label),
      );
}

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
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.calendar_month)),
                title: Text(
                  'سال‌های مالی',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('سال‌های قابل استفاده برای شرکت فعال'),
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
                    trailing: row['disabled'] == 1
                        ? const Chip(label: Text('غیرفعال'))
                        : const Chip(label: Text('فعال')),
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
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(Icons.lock_outline)),
                title: Text(
                  'قفل‌های دوره',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('بازه‌های بسته‌شده در شرکت فعال'),
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
                    trailing: const Icon(Icons.lock, size: 18),
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
    final availableTypes = snapshot.detailTypes
        .where((type) => !draft.rules.any((rule) => rule.detailType == type))
        .toList(growable: false);

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
                                'مشخصات حساب و قواعد تفصیلی در سطح شرکت فعال',
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
                            const SizedBox(width: 14),
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('حساب گروه'),
                                subtitle: const Text('حساب گروه سندپذیر نیست'),
                                value: draft.isGroup,
                                onChanged: (value) =>
                                    cubit.updateAccount(isGroup: value),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'قواعد تفصیلی و ابعاد',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (!draft.isGroup && availableTypes.isNotEmpty)
                              SizedBox(
                                width: 260,
                                child: DropdownButtonFormField<String>(
                                  value: null,
                                  decoration: const InputDecoration(
                                      labelText: 'افزودن نوع تفصیلی'),
                                  items: [
                                    for (final type in availableTypes)
                                      DropdownMenuItem(
                                        value: type,
                                        child: Text(_detailTypeLabel(type)),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      cubit.addDetailRule(value);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (draft.isGroup)
                          const Card(
                            color: Color(0xfffff8e8),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'حساب گروه مستقیماً سند نمی‌پذیرد؛ قواعد تفصیلی روی حساب‌های نهایی تعریف می‌شوند.',
                              ),
                            ),
                          )
                        else if (draft.rules.isEmpty)
                          const Card(
                            color: Color(0xfff8fafd),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'برای این حساب تفصیلی الزامی نیست. در صورت نیاز، نوع تفصیلی مجاز را اضافه کنید.',
                              ),
                            ),
                          )
                        else
                          for (var index = 0;
                              index < draft.rules.length;
                              index++)
                            _DetailRuleEditor(
                              index: index,
                              rule: draft.rules[index],
                              details: snapshot.floatingDetails,
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
                          label: const Text('ذخیره حساب و قواعد'),
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

class _DetailRuleEditor extends StatelessWidget {
  const _DetailRuleEditor({
    required this.index,
    required this.rule,
    required this.details,
  });

  final int index;
  final AccountDetailRuleDraft rule;
  final List<Map<String, dynamic>> details;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganizationSettingsCubit>();
    final matchingDetails = details
        .where((row) => row['detail_type']?.toString() == rule.detailType)
        .toList(growable: false);
    final defaultValue = matchingDetails
            .any((row) => row['name']?.toString() == rule.defaultFloatingDetail)
        ? rule.defaultFloatingDetail
        : null;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: const Color(0xfff8fafd),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _detailTypeLabel(rule.detailType),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: (value) =>
                      cubit.updateDetailRule(index, enabled: value),
                ),
                const Text('فعال'),
                const SizedBox(width: 14),
                Switch(
                  value: rule.required,
                  onChanged: rule.enabled
                      ? (value) =>
                          cubit.updateDetailRule(index, required: value)
                      : null,
                ),
                const Text('اجباری'),
                IconButton(
                  tooltip: 'حذف قاعده',
                  onPressed: () => cubit.removeDetailRule(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: defaultValue,
                    decoration:
                        const InputDecoration(labelText: 'تفصیلی پیش‌فرض'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('بدون پیش‌فرض')),
                      for (final detail in matchingDetails)
                        DropdownMenuItem(
                          value: detail['name']?.toString(),
                          child:
                              Text(detail['detail_title']?.toString() ?? '-'),
                        ),
                    ],
                    onChanged: (value) => cubit.updateDetailRule(
                      index,
                      defaultFloatingDetail: value ?? '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('from-$index-${rule.detailType}'),
                    initialValue: rule.validFrom,
                    decoration: const InputDecoration(
                      labelText: 'معتبر از',
                      hintText: 'YYYY-MM-DD',
                    ),
                    onChanged: (value) =>
                        cubit.updateDetailRule(index, validFrom: value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('to-$index-${rule.detailType}'),
                    initialValue: rule.validTo,
                    decoration: const InputDecoration(
                      labelText: 'معتبر تا',
                      hintText: 'YYYY-MM-DD',
                    ),
                    onChanged: (value) =>
                        cubit.updateDetailRule(index, validTo: value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
