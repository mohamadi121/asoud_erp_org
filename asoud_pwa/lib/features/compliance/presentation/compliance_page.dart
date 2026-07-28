import 'package:asoud_pwa/features/compliance/domain/compliance_gateway.dart';
import 'package:asoud_pwa/features/compliance/domain/compliance_snapshot.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';

class CompliancePage extends StatefulWidget {
  const CompliancePage(
      {required this.context, required this.gateway, super.key});

  final WorkContext context;
  final ComplianceGateway gateway;

  @override
  State<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends State<CompliancePage> {
  late Future<ComplianceSnapshot> snapshot =
      widget.gateway.load(widget.context);

  void reload() =>
      setState(() => snapshot = widget.gateway.load(widget.context));

  @override
  Widget build(BuildContext context) => FutureBuilder<ComplianceSnapshot>(
        future: snapshot,
        builder: (context, state) {
          if (state.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.hasError) {
            return Center(
              child: FilledButton.tonal(
                onPressed: reload,
                child: Text('تلاش مجدد: ${state.error}'),
              ),
            );
          }
          final data = state.requireData;
          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await snapshot;
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'انطباق و اتصال‌ها — ${widget.context.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _status(
                  context,
                  'سامانه مؤدیان',
                  data.taxConfigured
                      ? 'محیط ${data.taxEnvironment} • صف ${data.taxQueued} • پذیرفته ${data.taxAccepted}'
                      : 'پیکربندی نشده',
                  data.taxConfigured,
                ),
                _status(
                  context,
                  'بانک و صیاد',
                  'اتصال‌ها ${data.bankConnections.values.fold(0, (a, b) => a + b)}'
                      ' • تطبیق‌نشده ${data.unmatchedLines}'
                      ' • عملیات باز صیاد ${data.openSayadOperations}',
                  data.bankConnections.isNotEmpty,
                ),
                _status(
                  context,
                  'تلفیق چندارزی',
                  'سیاست نرخ ${data.fxPolicy ? 'فعال' : 'تعریف‌نشده'}'
                      ' • نرخ‌های تأییدشده ${data.approvedRates}',
                  data.fxPolicy,
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_user_outlined),
                    title: Text('مرز کنترل تولید'),
                    subtitle: Text(
                      'فعال‌سازی رسمی فقط پس از قرارداد، گواهی، کلید و آزمون پذیرش ارائه‌دهنده انجام می‌شود.',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _status(
    BuildContext context,
    String title,
    String subtitle,
    bool ready,
  ) =>
      Card(
        child: ListTile(
          leading: Icon(
            ready ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: ready ? Colors.green : Theme.of(context).colorScheme.error,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}
