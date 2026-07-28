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
        create: (_) => OrganizationSettingsCubit(gateway, this.context)
          ..show(initialView)
          ..load(),
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
                      SettingsView.financial => const _FinancialSettings(),
                    },
                  ),
                ],
              ),
              if (state.draft != null) _Wizard(draft: state.draft!),
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
  const _FinancialSettings();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('تنظیمات عمومی حسابداری',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: const [
                  _ReadOnlyField('ارز پایه', 'ریال ایران (IRR)'),
                  _ReadOnlyField('سال مالی', 'سال مالی ۱۴۰۵'),
                  _ReadOnlyField('نمودار حساب‌ها', 'استاندارد حسابداری ایران'),
                  _ReadOnlyField('دوره‌ها', '۱۲ دوره ماهانه'),
                  _ReadOnlyField('روش بستن سال', 'اختتامیه و افتتاحیه واقعی'),
                  _ReadOnlyField('گزارش هلدینگ', 'مستقل و تلفیقی'),
                ],
              ),
            ),
          ),
        ],
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
