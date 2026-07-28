import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operations_snapshot.dart';
import 'package:asoud_pwa/features/operations/presentation/operation_form.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({
    required this.context,
    required this.gateway,
    this.documentTypes,
    super.key,
  });

  final WorkContext context;
  final OperationsGateway gateway;
  final Set<String>? documentTypes;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  late Future<(OperationsSnapshot, OperationalWorkbench)> data = _load();

  Future<(OperationsSnapshot, OperationalWorkbench)> _load() async => (
        await widget.gateway.load(widget.context),
        await widget.gateway.loadWorkbench(widget.context)
      );

  Future<void> _refresh() async {
    setState(() => data = _load());
    await data;
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(OperationsSnapshot, OperationalWorkbench)>(
        future: data,
        builder: (context, state) {
          if (state.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.hasError) {
            return _ErrorPanel(error: state.error, retry: _refresh);
          }
          final (snapshot, workbench) = state.requireData;
          final filteredWorkbench = OperationalWorkbench(
            contracts: widget.documentTypes == null
                ? workbench.contracts
                : workbench.contracts
                    .where((item) =>
                        widget.documentTypes!.contains(item.documentType))
                    .toList(growable: false),
            documents: widget.documentTypes == null
                ? workbench.documents
                : workbench.documents
                    .where((item) =>
                        widget.documentTypes!.contains(item.documentType))
                    .toList(growable: false),
          );
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                ListTile(
                  title: Text(widget.context.label),
                  subtitle: const Text('میزکار عملیات روزانه'),
                  trailing: IconButton(
                    tooltip: 'به‌روزرسانی',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'خلاصه'),
                    Tab(text: 'اسناد و عملیات'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _Dashboard(snapshot: snapshot),
                      _Documents(
                        workbench: filteredWorkbench,
                        gateway: widget.gateway,
                        workContext: widget.context,
                        refresh: _refresh,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.snapshot});

  final OperationsSnapshot snapshot;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Metric(title: 'فروش', value: snapshot.sales),
          _Metric(title: 'خرید', value: snapshot.purchases),
          _Metric(title: 'دریافت', value: snapshot.receipts),
          _Metric(title: 'پرداخت', value: snapshot.payments),
          _Metric(title: 'موجودی', value: snapshot.stockQty),
          _Metric(title: 'ارزش موجودی', value: snapshot.stockValue),
        ],
      );
}

class _Documents extends StatelessWidget {
  const _Documents({
    required this.workbench,
    required this.gateway,
    required this.workContext,
    required this.refresh,
  });

  final OperationalWorkbench workbench;
  final OperationsGateway gateway;
  final WorkContext workContext;
  final Future<void> Function() refresh;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final contract in workbench.contracts)
                FilledButton.tonalIcon(
                  onPressed: () => _create(context, contract),
                  icon: const Icon(Icons.add),
                  label: Text(contract.label),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('آخرین اسناد', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (workbench.documents.isEmpty)
            const Card(
              child: ListTile(title: Text('سندی در این محدوده ثبت نشده است.')),
            ),
          for (final document in workbench.documents)
            Card(
              child: ListTile(
                title: Text(document.name),
                subtitle: Text(
                  '${document.documentType} • ${document.postingDate ?? '-'}'
                  '${document.amount == null ? '' : ' • ${document.amount}'}',
                ),
                leading: Icon(
                  document.docstatus == 1
                      ? Icons.verified
                      : document.docstatus == 2
                          ? Icons.cancel
                          : Icons.edit_note,
                ),
                trailing: document.documentType == 'ASOUD Cheque'
                    ? null
                    : document.documentType == 'ASOUD Intercompany Transfer' &&
                            document.status == 'Requested'
                        ? IconButton(
                            tooltip: 'تأیید مبدأ',
                            icon: const Icon(Icons.approval_outlined),
                            onPressed: () => _transition(
                              context,
                              document,
                              'approve_source',
                            ),
                          )
                        : document.documentType ==
                                    'ASOUD Intercompany Transfer' &&
                                document.status == 'Source Approved'
                            ? IconButton(
                                tooltip: 'تأیید مقصد و ثبت دوطرفه',
                                icon: const Icon(Icons.domain_verification),
                                onPressed: () => _transition(
                                  context,
                                  document,
                                  'accept_destination',
                                ),
                              )
                            : document.docstatus == 0
                                ? IconButton(
                                    tooltip: 'ثبت نهایی',
                                    icon: const Icon(Icons.task_alt),
                                    onPressed: () => _transition(
                                        context, document, 'submit'),
                                  )
                                : document.docstatus == 1 &&
                                        document.documentType !=
                                            'ASOUD Intercompany Transfer'
                                    ? IconButton(
                                        tooltip: 'ابطال کنترل‌شده',
                                        icon: const Icon(Icons.undo),
                                        onPressed: () => _transition(
                                            context, document, 'cancel'),
                                      )
                                    : null,
              ),
            ),
        ],
      );

  Future<void> _create(BuildContext context, OperationContract contract) async {
    final payload = await showOperationForm(
      context,
      contract: contract,
      gateway: gateway,
    );
    if (payload == null || !context.mounted) return;
    try {
      final name = await gateway.createDraft(
        context: workContext,
        documentType: contract.documentType,
        payload: payload,
      );
      await refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('پیش‌نویس $name ایجاد شد.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _transition(
      BuildContext context, OperationalDocument document, String action) async {
    var reason = '';
    if (action == 'cancel') {
      final controller = TextEditingController();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('علت ابطال'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'علت مستند و الزامی',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ادامه'),
            ),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (accepted != true || reason.isEmpty) return;
    }
    try {
      await gateway.transition(
        documentType: document.documentType,
        name: document.name,
        action: action,
        reason: reason,
      );
      await refresh();
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value});

  final String title;
  final double value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(title),
          trailing: Text(
            value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.retry});

  final Object? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString()),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: retry,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString())),
  );
}
