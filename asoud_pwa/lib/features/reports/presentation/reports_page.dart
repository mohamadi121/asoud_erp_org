import 'package:asoud_pwa/core/download/download.dart';
import 'package:asoud_pwa/features/reports/domain/reports_gateway.dart';
import 'package:asoud_pwa/features/reports/domain/standard_report.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    required this.context,
    required this.gateway,
    super.key,
  });

  final WorkContext context;
  final ReportsGateway gateway;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const reportTypes = {
    'journal': 'دفتر روزنامه',
    'general_ledger': 'دفتر کل و معین',
    'floating_detail_ledger': 'دفتر تفصیلی شناور',
    'trial_balance': 'تراز آزمایشی شش‌ستونی',
    'balance_sheet': 'صورت وضعیت مالی',
    'profit_and_loss': 'صورت سود و زیان',
  };

  final fromDate = TextEditingController(text: '2026-03-21');
  final toDate = TextEditingController(text: '2027-03-20');
  String reportType = 'trial_balance';
  Future<StandardReport>? report;

  @override
  void dispose() {
    fromDate.dispose();
    toDate.dispose();
    super.dispose();
  }

  void load() => setState(
        () => report = widget.gateway.load(
          context: widget.context,
          reportType: reportType,
          fromDate: fromDate.text,
          toDate: toDate.text,
        ),
      );

  void export(String format) => downloadUrl(
        widget.gateway.exportUrl(
          context: widget.context,
          reportType: reportType,
          fromDate: fromDate.text,
          toDate: toDate.text,
          fileFormat: format,
        ),
      );

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Text(
            'گزارش‌های استاندارد ایران',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(widget.context.label),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: reportType,
                    items: reportTypes.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => reportType = value ?? reportType),
                    decoration: const InputDecoration(labelText: 'نوع گزارش'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromDate,
                          decoration: const InputDecoration(
                            labelText: 'از تاریخ استاندارد',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: toDate,
                          decoration: const InputDecoration(
                            labelText: 'تا تاریخ استاندارد',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.query_stats),
                    label: const Text('اجرای گزارش'),
                  ),
                ],
              ),
            ),
          ),
          if (report != null)
            FutureBuilder<StandardReport>(
              future: report,
              builder: (context, state) {
                if (state.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (state.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(state.error.toString()),
                    ),
                  );
                }
                return _ReportResult(
                  report: state.requireData,
                  onExport: export,
                );
              },
            ),
        ],
      );
}

class _ReportResult extends StatelessWidget {
  const _ReportResult({
    required this.report,
    required this.onExport,
  });

  final StandardReport report;
  final ValueChanged<String> onExport;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(report.title,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                'دوره ${report.fromDateJalali} تا ${report.toDateJalali}'
                ' — ${report.rows.length} ردیف — ${report.currency}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onExport('csv'),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExport('xlsx'),
                    icon: const Icon(Icons.grid_on_outlined),
                    label: const Text('Excel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onExport('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: report.columns
                      .map((column) => DataColumn(label: Text(column.label)))
                      .toList(growable: false),
                  rows: report.rows
                      .take(500)
                      .map(
                        (row) => DataRow(
                          cells: report.columns
                              .map(
                                (column) =>
                                    DataCell(Text('${row[column.key] ?? ''}')),
                              )
                              .toList(growable: false),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              if (report.rows.length > 500)
                const Text(
                  'برای کارایی رابط، ۵۰۰ ردیف اول نمایش داده شده است؛ خروجی فایل کامل است.',
                ),
              const Divider(),
              Wrap(
                spacing: 8,
                children: report.totals.entries
                    .map((entry) =>
                        Chip(label: Text('${entry.key}: ${entry.value}')))
                    .toList(growable: false),
              ),
              SelectableText(
                'Checksum: ${report.checksum}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}
