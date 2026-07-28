import 'package:asoud_pwa/features/hr/domain/hr_gateway.dart';
import 'package:asoud_pwa/features/hr/domain/hr_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';

class HrPage extends StatefulWidget {
  const HrPage({
    required this.context,
    required this.gateway,
    super.key,
  });

  final WorkContext context;
  final HrGateway gateway;

  @override
  State<HrPage> createState() => _HrPageState();
}

class _HrPageState extends State<HrPage> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  HrDashboard? dashboard;
  List<HrEmployeeSummary> employees = const [];
  List<WorkReportSummary> reports = const [];
  List<CommunicationSummary> communications = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.gateway.loadDashboard(widget.context),
        widget.gateway.loadEmployees(widget.context),
        widget.gateway.loadWorkReports(widget.context),
        widget.gateway.loadCommunications(widget.context),
      ]);
      if (!mounted) return;
      setState(() {
        dashboard = values[0] as HrDashboard;
        employees = values[1] as List<HrEmployeeSummary>;
        reports = values[2] as List<WorkReportSummary>;
        communications = values[3] as List<CommunicationSummary>;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Material(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: tabs,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'داشبورد'),
                      Tab(text: 'پرسنل'),
                      Tab(text: 'گزارش کار'),
                      Tab(text: 'مکاتبات'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'بازخوانی',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? _ErrorState(message: error!, retry: _reload)
                    : TabBarView(
                        controller: tabs,
                        children: [
                          _dashboard(),
                          _employees(),
                          _reports(),
                          _communications(),
                        ],
                      ),
          ),
        ],
      );

  Widget _dashboard() {
    final value = dashboard!;
    final cards = [
      ('پرسنل فعال', value.activeEmployees, Icons.groups_outlined),
      ('گزارش امروز', value.todayReports, Icons.fact_check_outlined),
      ('بدون گزارش', value.missingReports, Icons.warning_amber_outlined),
      ('مکاتبات باز', value.openCommunications, Icons.mail_outline),
      ('اقدامات باز', value.openActions, Icons.task_alt_outlined),
      ('اقدامات من', value.myOpenActions, Icons.assignment_ind_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('نمای منابع انسانی',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: 210,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(card.$3,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Text(card.$1)),
                          Text(
                            '${card.$2}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _employees() => _TableCard(
        title: 'پرسنل',
        columns: const ['نام', 'واحد', 'سمت', 'وضعیت'],
        rows: employees
            .map((row) => [
                  row.employeeName,
                  row.department ?? '—',
                  row.designation ?? '—',
                  row.status,
                ])
            .toList(growable: false),
      );

  Widget _reports() => Stack(
        children: [
          _TableCard(
            title: 'گزارش‌های روزانه',
            columns: const ['کارمند', 'تاریخ', 'مدت', 'وضعیت', 'تأیید'],
            rows: reports
                .map((row) => [
                      row.employeeName,
                      row.reportDate,
                      '${row.totalMinutes} دقیقه',
                      row.status,
                      row.approvalStatus ?? '—',
                    ])
                .toList(growable: false),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: FloatingActionButton.extended(
              onPressed: _createReport,
              icon: const Icon(Icons.add),
              label: const Text('گزارش جدید'),
            ),
          ),
        ],
      );

  Widget _communications() => Stack(
        children: [
          _TableCard(
            title: 'مکاتبات سازمانی',
            columns: const ['موضوع', 'فرستنده', 'اولویت', 'محرمانگی', 'وضعیت'],
            rows: communications
                .map((row) => [
                      row.subject,
                      row.sender,
                      row.priority,
                      row.confidentiality,
                      row.status,
                    ])
                .toList(growable: false),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: FloatingActionButton.extended(
              onPressed: _createCommunication,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('مکاتبه جدید'),
            ),
          ),
        ],
      );

  Future<void> _createReport() async {
    final activity = TextEditingController();
    final summary = TextEditingController();
    final minutes = TextEditingController(text: '60');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ثبت گزارش روزانه'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: activity,
                  decoration: const InputDecoration(labelText: 'فعالیت')),
              TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مدت به دقیقه')),
              TextField(
                  controller: summary,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'خلاصه روز')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ثبت')),
        ],
      ),
    );
    if (accepted == true && activity.text.trim().isNotEmpty) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await widget.gateway.createWorkReport(
        reportDate: today,
        activity: activity.text.trim(),
        minutes: int.tryParse(minutes.text) ?? 60,
        summary: summary.text.trim(),
      );
      await _reload();
    }
    activity.dispose();
    summary.dispose();
    minutes.dispose();
  }

  Future<void> _createCommunication() async {
    final subject = TextEditingController();
    final body = TextEditingController();
    final recipient = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مکاتبه جدید'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'موضوع')),
              TextField(
                  controller: recipient,
                  decoration:
                      const InputDecoration(labelText: 'نام کاربری گیرنده')),
              TextField(
                  controller: body,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'متن')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ذخیره پیش‌نویس')),
        ],
      ),
    );
    if (accepted == true &&
        subject.text.trim().isNotEmpty &&
        recipient.text.trim().isNotEmpty) {
      await widget.gateway.createCommunication(
        context: widget.context,
        type: 'Internal Letter',
        subject: subject.text.trim(),
        body: body.text.trim(),
        recipient: recipient.text.trim(),
        priority: 'Normal',
        confidentiality: 'Normal',
      );
      await _reload();
    }
    subject.dispose();
    body.dispose();
    recipient.dispose();
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('رکوردی برای نمایش وجود ندارد.')),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns
                          .map((item) => DataColumn(label: Text(item)))
                          .toList(),
                      rows: rows
                          .map(
                            (row) => DataRow(
                              cells: row
                                  .map((cell) => DataCell(Text(cell)))
                                  .toList(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('تلاش دوباره')),
          ],
        ),
      );
}
