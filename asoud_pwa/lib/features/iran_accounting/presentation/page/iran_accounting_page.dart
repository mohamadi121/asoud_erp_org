import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';

enum IranAccountingSection { dashboard, numbering }

class IranAccountingPage extends StatefulWidget {
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
  State<IranAccountingPage> createState() => _IranAccountingPageState();
}

class _IranAccountingPageState extends State<IranAccountingPage> {
  late Future<AccountingSettings> settings;
  late Future<List<AccountSummary>> chart;
  late Future<Map<String, dynamic>> numbering;
  late Future<List<Map<String, dynamic>>> closingRuns;
  final amount = TextEditingController(text: '1000');
  final jalaliDate = TextEditingController(text: '1405-01-01');
  final fromDate = TextEditingController(text: '2026-03-21');
  final toDate = TextEditingController(text: '2027-03-20');
  final numberingFiscalYear = TextEditingController(text: '1405');
  final numberingFromDate = TextEditingController(text: '2026-03-21');
  final numberingToDate = TextEditingController(text: '2027-03-20');
  final numberingReason = TextEditingController();
  late IranAccountingSection section;
  String inputUnit = 'TOMAN';
  String? amountResult;
  String? dateResult;
  String? numberingResult;
  List<TrialBalanceRow>? balanceRows;
  String? actionError;
  bool actionLoading = false;

  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
    settings = widget.gateway.loadSettings(widget.context.company);
    chart = widget.gateway.loadChartOfAccounts(widget.context.company);
    numbering = widget.gateway.loadNumberingOverview(widget.context.company);
    closingRuns = widget.gateway.loadClosingRuns(widget.context.company);
  }

  @override
  void dispose() {
    amount.dispose();
    jalaliDate.dispose();
    fromDate.dispose();
    toDate.dispose();
    numberingFiscalYear.dispose();
    numberingFromDate.dispose();
    numberingToDate.dispose();
    numberingReason.dispose();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() callback) async {
    setState(() {
      actionLoading = true;
      actionError = null;
    });
    try {
      await callback();
    } on Object catch (error) {
      setState(() => actionError = error.toString());
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AccountingSettings>(
        future: settings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final data = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'پایه حسابداری ایران',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(widget.context.label),
              const SizedBox(height: 16),
              SegmentedButton<IranAccountingSection>(
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
                selected: {section},
                onSelectionChanged: (value) =>
                    setState(() => section = value.first),
              ),
              const SizedBox(height: 16),
              if (section == IranAccountingSection.dashboard) ...[
                _iranSettingsOverview(data),
                const SizedBox(height: 16),
                _settingsCard(data),
                const SizedBox(height: 16),
                _amountCard(),
                const SizedBox(height: 16),
                _dateCard(),
                const SizedBox(height: 16),
                _trialBalanceCard(),
                const SizedBox(height: 16),
                _closingCard(),
              ] else ...[
                _numberingWorkspace(),
              ],
              if (actionLoading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (actionError != null) ...[
                const SizedBox(height: 12),
                Text(
                  actionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        },
      );

  Widget _iranSettingsOverview(AccountingSettings data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'داشبورد تنظیمات حسابداری ایران',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'وضعیت راه‌اندازی، تقویم، واحد مبلغ، نمودار حساب‌ها و عملیات پایان سال در سطح Company فعال.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _value('وضعیت', data.setupStatus),
                  _value('ارز دفتر کل', data.baseCurrency ?? '—'),
                  _value('واحد ورود', data.amountInputUnit ?? '—'),
                  _value('تقویم', data.calendarDisplay ?? '—'),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _numberingWorkspace() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _numberingCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تخصیص شماره قطعی',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'اسناد ثبت‌شده بر اساس تاریخ مرتب می‌شوند؛ شماره موقت حذف نمی‌شود.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _numberingField('سال مالی *', numberingFiscalYear),
                      _numberingField('از تاریخ *', numberingFromDate),
                      _numberingField('تا تاریخ *', numberingToDate),
                      _numberingField('دلیل اجرا *', numberingReason,
                          width: 520),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: actionLoading ? null : _finalizeNumbering,
                      icon: const Icon(Icons.numbers_outlined),
                      label: const Text('مرتب‌سازی و تخصیص شماره قطعی'),
                    ),
                  ),
                  if (numberingResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'عملیات با موفقیت ثبت شد: $numberingResult',
                      style: const TextStyle(
                        color: Color(0xff168a56),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );

  Widget _numberingField(
    String label,
    TextEditingController controller, {
    double width = 250,
  }) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
      );

  void _finalizeNumbering() {
    if ([
      numberingFiscalYear.text,
      numberingFromDate.text,
      numberingToDate.text,
      numberingReason.text,
    ].any((value) => value.trim().isEmpty)) {
      setState(
          () => actionError = 'تمام فیلدهای عملیات شماره‌گذاری الزامی هستند.');
      return;
    }
    _action(() async {
      final batch = await widget.gateway.finalizeNumbering(
        company: widget.context.company,
        fiscalYear: numberingFiscalYear.text.trim(),
        fromDate: numberingFromDate.text.trim(),
        toDate: numberingToDate.text.trim(),
        reason: numberingReason.text.trim(),
      );
      setState(() {
        numbering =
            widget.gateway.loadNumberingOverview(widget.context.company);
        numberingResult = batch;
        numberingReason.clear();
      });
    });
  }

  Widget _numberingCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Map<String, dynamic>>(
            future: numbering,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final counts = Map<String, dynamic>.from(
                snapshot.requireData['counts'] as Map? ?? const {},
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('رجیستر و شماره‌گذاری اسناد',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _value('موقت', '${counts['Temporary'] ?? 0}'),
                      _value('قطعی', '${counts['Final'] ?? 0}'),
                      _value('قفل', '${counts['Locked'] ?? 0}'),
                      _value('ابطال', '${counts['Cancelled'] ?? 0}'),
                    ],
                  ),
                  const Text(
                    'اجرای Batch، ادغام انتخابی و قفل دوره با نقش مدیر حسابداری انجام می‌شود.',
                  ),
                ],
              );
            },
          ),
        ),
      );

  Widget _closingCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: closingRuns,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final rows = snapshot.requireData;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('اختتامیه و افتتاحیه',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const Text('عملیات اختتامیه‌ای برای این شرکت ثبت نشده است.')
                  else
                    ...rows.map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: Text('${row['fiscal_year']} — ${row['status']}'),
                        subtitle: Text(
                          'Preflight: ${row['preflight_status']} | تطبیق: ${row['reconciliation_status']}',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );

  Widget _settingsCard(AccountingSettings data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تنظیمات شرکت',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _value('وضعیت', data.setupStatus),
                  _value('قالب حساب‌ها', data.coaTemplate ?? '—'),
                  _value('نسخه', data.setupVersion ?? '—'),
                  _value('واحد دفتر کل', data.baseCurrency ?? '—'),
                  _value('واحد ورود', data.amountInputUnit ?? '—'),
                  _value('تقویم', data.calendarDisplay ?? '—'),
                ],
              ),
              if (!data.isReady) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: actionLoading
                      ? null
                      : () => _action(() async {
                            final updated = await widget.gateway
                                .applySetup(widget.context.company);
                            setState(() => settings = Future.value(updated));
                          }),
                  child: const Text('راه‌اندازی حسابداری ایران'),
                ),
              ],
              if (data.isReady)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('مشاهده نمودار حساب‌ها'),
                  children: [
                    FutureBuilder<List<AccountSummary>>(
                      future: chart,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        return Column(
                          children: snapshot.requireData
                              .map(
                                (account) => ListTile(
                                  dense: true,
                                  leading: Icon(
                                    account.isGroup
                                        ? Icons.account_tree_outlined
                                        : Icons.receipt_long_outlined,
                                  ),
                                  title: Text(
                                    '${account.number} — ${account.title}',
                                  ),
                                  subtitle: Text(account.rootType),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      );

  Widget _amountCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تبدیل دقیق ریال و تومان',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
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
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: actionLoading
                    ? null
                    : () => _action(() async {
                          final result = await widget.gateway.convertAmount(
                            value: amount.text,
                            inputUnit: inputUnit,
                            outputUnit: inputUnit == 'IRR' ? 'TOMAN' : 'IRR',
                          );
                          setState(() => amountResult = result);
                        }),
                child: const Text('تبدیل'),
              ),
              if (amountResult != null) Text('نتیجه: $amountResult'),
            ],
          ),
        ),
      );

  Widget _dateCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تاریخ جلالی',
                  style: Theme.of(context).textTheme.titleMedium),
              TextField(
                controller: jalaliDate,
                decoration:
                    const InputDecoration(labelText: 'تاریخ شمسی YYYY-MM-DD'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: actionLoading
                    ? null
                    : () => _action(() async {
                          final result =
                              await widget.gateway.fromJalali(jalaliDate.text);
                          setState(() => dateResult = result);
                        }),
                child: const Text('تبدیل به تاریخ استاندارد'),
              ),
              if (dateResult != null) Text('تاریخ استاندارد: $dateResult'),
            ],
          ),
        ),
      );

  Widget _trialBalanceCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تراز آزمایشی پایه',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fromDate,
                      decoration: const InputDecoration(
                          labelText: 'از تاریخ استاندارد'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: toDate,
                      decoration: const InputDecoration(
                          labelText: 'تا تاریخ استاندارد'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: actionLoading
                    ? null
                    : () => _action(() async {
                          final rows = await widget.gateway.loadTrialBalance(
                            company: widget.context.company,
                            fromDate: fromDate.text,
                            toDate: toDate.text,
                          );
                          setState(() => balanceRows = rows);
                        }),
                child: const Text('دریافت تراز'),
              ),
              if (balanceRows != null) ...[
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
                    rows: balanceRows!
                        .map(
                          (row) => DataRow(
                            cells: [
                              DataCell(Text(row.accountNumber)),
                              DataCell(Text(row.account)),
                              DataCell(Text(row.debit)),
                              DataCell(Text(row.credit)),
                              DataCell(Text(row.balance)),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _value(String label, String value) => Chip(
        label: Text('$label: $value'),
      );
}
