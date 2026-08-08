import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/iran_accounting/presentation/bloc/iran_accounting_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IranAccountingPage extends StatelessWidget {
  const IranAccountingPage({
    required this.context,
    required this.gateway,
    this.initialSection = IranAccountingSection.dashboard,
    super.key,
  });

  final WorkContext context;
  final IranAccountingGateway gateway;
  final IranAccountingSection initialSection;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => IranAccountingCubit(
          gateway,
          this.context,
          initialSection: initialSection,
        )..load(),
        child: _IranAccountingView(workContext: this.context),
      );
}

class _IranAccountingView extends StatefulWidget {
  const _IranAccountingView({required this.workContext});

  final WorkContext workContext;

  @override
  State<_IranAccountingView> createState() => _IranAccountingViewState();
}

class _IranAccountingViewState extends State<_IranAccountingView> {
  final amount = TextEditingController(text: '1000');
  final jalaliDate = TextEditingController(text: '1405-01-01');
  final fromDate = TextEditingController(text: '2026-03-21');
  final toDate = TextEditingController(text: '2027-03-20');
  final numberingFromDate = TextEditingController();
  final numberingToDate = TextEditingController();
  final numberingReason = TextEditingController();
  final consolidationReason = TextEditingController();
  String inputUnit = 'TOMAN';
  String? fiscalYear;

  @override
  void dispose() {
    amount.dispose();
    jalaliDate.dispose();
    fromDate.dispose();
    toDate.dispose();
    numberingFromDate.dispose();
    numberingToDate.dispose();
    numberingReason.dispose();
    consolidationReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<IranAccountingCubit, IranAccountingState>(
        builder: (context, state) {
          if (state.phase == IranAccountingPhase.loading &&
              state.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.settings == null) {
            return _Failure(
                error: state.error,
                retry: context.read<IranAccountingCubit>().load);
          }
          return ColoredBox(
            color: AsoudColors.canvas,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _Header(context: widget.workContext),
                const SizedBox(height: 16),
                _SectionSelector(selected: state.section),
                if (state.phase == IranAccountingPhase.saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  _Notice(text: state.error!, error: true),
                ],
                if (state.message != null) ...[
                  const SizedBox(height: 12),
                  _Notice(text: state.message!),
                ],
                const SizedBox(height: 16),
                if (state.section == IranAccountingSection.dashboard)
                  _dashboard(state)
                else
                  _numbering(state),
              ],
            ),
          );
        },
      );

  Widget _dashboard(IranAccountingState state) {
    final settings = state.settings!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Overview(settings: settings),
        const SizedBox(height: 16),
        _SetupCard(
          settings: settings,
          chart: state.chart,
          saving: state.phase == IranAccountingPhase.saving,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 1000
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: width, child: _amountCard(state)),
                SizedBox(width: width, child: _dateCard(state)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _trialBalanceCard(state),
        const SizedBox(height: 16),
        _ClosingCard(rows: state.closingRuns),
      ],
    );
  }

  Widget _numbering(IranAccountingState state) {
    final years = state.numberingWorkspace.fiscalYears;
    final selectedYear = years.any((row) => row.name == fiscalYear)
        ? fiscalYear
        : years.isEmpty
            ? null
            : years.first.name;
    final selectedYearRow =
        years.where((row) => row.name == selectedYear).firstOrNull;
    if (numberingFromDate.text.isEmpty && selectedYearRow != null) {
      numberingFromDate.text = selectedYearRow.fromDate;
      numberingToDate.text = selectedYearRow.toDate;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberingSummary(data: state.numbering),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CardTitle(
                  title: 'تخصیص شماره قطعی',
                  subtitle:
                      'مرتب‌سازی بر اساس تاریخ؛ شماره موقت برای همیشه حفظ می‌شود.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration:
                            const InputDecoration(labelText: 'سال مالی *'),
                        items: [
                          for (final year in years)
                            DropdownMenuItem(
                              value: year.name,
                              child: Text(year.name),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() => fiscalYear = value);
                          final year = years
                              .where((row) => row.name == value)
                              .firstOrNull;
                          if (year != null) {
                            numberingFromDate.text = year.fromDate;
                            numberingToDate.text = year.toDate;
                          }
                        },
                      ),
                    ),
                    _dateField('از تاریخ *', numberingFromDate),
                    _dateField('تا تاریخ *', numberingToDate),
                    SizedBox(
                      width: 500,
                      child: TextField(
                        controller: numberingReason,
                        decoration:
                            const InputDecoration(labelText: 'دلیل اجرا *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: state.phase == IranAccountingPhase.saving
                        ? null
                        : () => context
                            .read<IranAccountingCubit>()
                            .finalizeNumbering(
                              fiscalYear: selectedYear ?? '',
                              fromDate: numberingFromDate.text,
                              toDate: numberingToDate.text,
                              reason: numberingReason.text,
                            ),
                    icon: const Icon(Icons.numbers_outlined),
                    label: const Text('مرتب‌سازی و تخصیص شماره قطعی'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _consolidationCard(state),
      ],
    );
  }

  Widget _consolidationCard(IranAccountingState state) {
    final workspace = state.numberingWorkspace;
    final dates = workspace.availableDates;
    final selectedDate =
        workspace.postingDate.isNotEmpty ? workspace.postingDate : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(
              title: 'ادغام انتخابی اسناد روزانه',
              subtitle:
                  'حداقل دو سند موقت از یک Company و یک تاریخ را انتخاب کنید.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    value: selectedDate,
                    decoration: const InputDecoration(labelText: 'تاریخ اسناد'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('همه تاریخ‌ها'),
                      ),
                      for (final date in dates)
                        DropdownMenuItem(value: date, child: Text(date)),
                    ],
                    onChanged: (value) => context
                        .read<IranAccountingCubit>()
                        .filterCandidates(value),
                  ),
                ),
                const Spacer(),
                Text('${state.selectedDocuments.length} سند انتخاب شده'),
              ],
            ),
            const SizedBox(height: 12),
            if (workspace.candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('سند موقت قابل ادغام وجود ندارد.')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('انتخاب')),
                    DataColumn(label: Text('تاریخ')),
                    DataColumn(label: Text('شماره موقت')),
                    DataColumn(label: Text('نوع سند')),
                    DataColumn(label: Text('سند منبع')),
                  ],
                  rows: [
                    for (final row in workspace.candidates)
                      DataRow(
                        selected: state.selectedDocuments.contains(row.name),
                        cells: [
                          DataCell(
                            Checkbox(
                              value: state.selectedDocuments.contains(row.name),
                              onChanged: (value) => context
                                  .read<IranAccountingCubit>()
                                  .toggleDocument(row.name, value ?? false),
                            ),
                          ),
                          DataCell(Text(row.postingDate)),
                          DataCell(Text(row.temporaryNumber)),
                          DataCell(Text(row.sourceType)),
                          DataCell(Text(row.sourceName)),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: consolidationReason,
                    decoration:
                        const InputDecoration(labelText: 'دلیل ادغام *'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: state.phase == IranAccountingPhase.saving
                      ? null
                      : () => context
                          .read<IranAccountingCubit>()
                          .consolidateSelected(consolidationReason.text),
                  icon: const Icon(Icons.merge_type),
                  label: const Text('ثبت ادغام روزانه'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller) => SizedBox(
        width: 300,
        child: TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          onTap: () => _pickDate(controller),
        ),
      );

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (date != null) {
      controller.text = date.toIso8601String().split('T').first;
    }
  }

  Widget _amountCard(IranAccountingState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                title: 'تبدیل دقیق ریال و تومان',
                subtitle: 'دفتر کل همیشه مبلغ را به ریال نگهداری می‌کند.',
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: 'مبلغ'),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: inputUnit,
                  items: const [
                    DropdownMenuItem(value: 'IRR', child: Text('ریال')),
                    DropdownMenuItem(value: 'TOMAN', child: Text('تومان')),
                  ],
                  onChanged: (value) =>
                      setState(() => inputUnit = value ?? inputUnit),
                ),
              ]),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context
                    .read<IranAccountingCubit>()
                    .convertAmount(value: amount.text, inputUnit: inputUnit),
                child: const Text('تبدیل'),
              ),
              if (state.amountResult != null)
                Text('نتیجه: ${state.amountResult}'),
            ],
          ),
        ),
      );

  Widget _dateCard(IranAccountingState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                title: 'تاریخ جلالی',
                subtitle: 'نمایش شمسی و ذخیره تاریخ استاندارد.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jalaliDate,
                decoration:
                    const InputDecoration(labelText: 'تاریخ شمسی YYYY-MM-DD'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context
                    .read<IranAccountingCubit>()
                    .convertDate(jalaliDate.text),
                child: const Text('تبدیل به تاریخ استاندارد'),
              ),
              if (state.dateResult != null)
                Text('تاریخ استاندارد: ${state.dateResult}'),
            ],
          ),
        ),
      );

  Widget _trialBalanceCard(IranAccountingState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                title: 'تراز آزمایشی پایه',
                subtitle: 'کنترل سریع بازه مالی Company فعال.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _dateField('از تاریخ', fromDate),
                  _dateField('تا تاریخ', toDate),
                  FilledButton.tonal(
                    onPressed: () => context
                        .read<IranAccountingCubit>()
                        .loadTrialBalance(fromDate.text, toDate.text),
                    child: const Text('دریافت تراز'),
                  ),
                ],
              ),
              if (state.balanceRows != null) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('کد')),
                      DataColumn(label: Text('حساب')),
                      DataColumn(label: Text('بدهکار')),
                      DataColumn(label: Text('بستانکار')),
                      DataColumn(label: Text('مانده')),
                    ],
                    rows: [
                      for (final row in state.balanceRows!)
                        DataRow(cells: [
                          DataCell(Text(row.accountNumber)),
                          DataCell(Text(row.account)),
                          DataCell(Text(row.debit)),
                          DataCell(Text(row.credit)),
                          DataCell(Text(row.balance)),
                        ]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.context});
  final WorkContext context;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'پایه حسابداری ایران',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(this.context.label,
              style: const TextStyle(color: AsoudColors.muted)),
        ],
      );
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.selected});
  final IranAccountingSection selected;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: SegmentedButton<IranAccountingSection>(
          segments: const [
            ButtonSegment(
              value: IranAccountingSection.dashboard,
              icon: Icon(Icons.dashboard_customize_outlined),
              label: Text('داشبورد تنظیمات'),
            ),
            ButtonSegment(
              value: IranAccountingSection.numbering,
              icon: Icon(Icons.format_list_numbered_rtl),
              label: Text('شماره‌گذاری اسناد'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (value) =>
              context.read<IranAccountingCubit>().showSection(value.first),
        ),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.settings});
  final AccountingSettings settings;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                title: 'داشبورد تنظیمات حسابداری ایران',
                subtitle:
                    'وضعیت راه‌اندازی، تقویم، واحد مبلغ و الگوی حساب‌های Company فعال.',
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Value(label: 'وضعیت', value: settings.setupStatus),
                _Value(
                    label: 'ارز دفتر کل', value: settings.baseCurrency ?? '—'),
                _Value(
                    label: 'واحد ورود', value: settings.amountInputUnit ?? '—'),
                _Value(label: 'تقویم', value: settings.calendarDisplay ?? '—'),
              ]),
            ],
          ),
        ),
      );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.settings,
    required this.chart,
    required this.saving,
  });
  final AccountingSettings settings;
  final List<AccountSummary> chart;
  final bool saving;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                title: 'تنظیمات شرکت و نمودار حساب‌ها',
                subtitle: 'قالب ایرانی بدون تغییر ERPNext Core.',
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Value(label: 'قالب', value: settings.coaTemplate ?? '—'),
                _Value(label: 'نسخه', value: settings.setupVersion ?? '—'),
              ]),
              if (!settings.isReady) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: saving
                      ? null
                      : context.read<IranAccountingCubit>().applySetup,
                  child: const Text('راه‌اندازی حسابداری ایران'),
                ),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('مشاهده نمودار حساب‌ها (${chart.length})'),
                children: [
                  for (final account in chart)
                    ListTile(
                      dense: true,
                      leading: Icon(account.isGroup
                          ? Icons.account_tree_outlined
                          : Icons.receipt_long_outlined),
                      title: Text('${account.number} — ${account.title}'),
                      subtitle: Text(account.rootType),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _NumberingSummary extends StatelessWidget {
  const _NumberingSummary({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final counts =
        Map<String, dynamic>.from(data['counts'] as Map? ?? const {});
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(
              title: 'رجیستر و شماره‌گذاری قانونی',
              subtitle: 'وضعیت اسناد Company فعال.',
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Value(label: 'موقت', value: '${counts['Temporary'] ?? 0}'),
              _Value(label: 'قطعی', value: '${counts['Final'] ?? 0}'),
              _Value(label: 'قفل', value: '${counts['Locked'] ?? 0}'),
              _Value(label: 'ابطال', value: '${counts['Cancelled'] ?? 0}'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                title: 'اختتامیه و افتتاحیه',
                subtitle: 'Preflight، ثبت واقعی و تطبیق پایان سال.',
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('عملیات پایان سالی ثبت نشده است.'),
                )
              else
                for (final row in rows)
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text('${row['fiscal_year']} — ${row['status']}'),
                    subtitle: Text(
                      'Preflight: ${row['preflight_status']} | تطبیق: ${row['reconciliation_status']}',
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AsoudColors.muted)),
        ],
      );
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? const Color(0xffffeeee) : const Color(0xffe9f8f0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: error
                ? Theme.of(context).colorScheme.error
                : const Color(0xff168a56),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.retry});
  final String? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error ?? 'بارگذاری اطلاعات ناموفق بود.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('تلاش دوباره')),
          ],
        ),
      );
}
