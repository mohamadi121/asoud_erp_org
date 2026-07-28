import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_gateway.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_snapshot.dart';
import 'package:flutter/material.dart';

class TreasuryPage extends StatefulWidget {
  const TreasuryPage({
    required this.context,
    required this.gateway,
    super.key,
  });

  final WorkContext context;
  final TreasuryGateway gateway;

  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  late Future<TreasurySnapshot> snapshot = widget.gateway.load(widget.context);

  void reload() =>
      setState(() => snapshot = widget.gateway.load(widget.context));

  @override
  Widget build(BuildContext context) => FutureBuilder<TreasurySnapshot>(
        future: snapshot,
        builder: (context, state) {
          if (state.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.error.toString()),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: reload,
                    child: const Text('تلاش مجدد'),
                  ),
                ],
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Text(
                  'خزانه‌داری — ${widget.context.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('مانده تا تاریخ ${data.asOfDate}'),
                const SizedBox(height: 12),
                _BalanceCard(
                  title: 'بانک',
                  icon: Icons.account_balance,
                  value: data.bank,
                ),
                _BalanceCard(
                  title: 'صندوق',
                  icon: Icons.point_of_sale,
                  value: data.cash,
                ),
                _BalanceCard(
                  title: 'تنخواه',
                  icon: Icons.wallet_outlined,
                  value: data.pettyCash,
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('تسویه‌های باز تنخواه'),
                    trailing: Text(data.unsettledPettyCashClaims.toString()),
                  ),
                ),
                if (data.cheques.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('وضعیت چک‌ها',
                      style: Theme.of(context).textTheme.titleMedium),
                  ...data.cheques.entries.map(
                    (entry) => ListTile(
                      dense: true,
                      title: Text(_chequeLabel(entry.key)),
                      trailing: Text(_amount(entry.value)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text('حساب‌های خزانه',
                    style: Theme.of(context).textTheme.titleMedium),
                ...data.accounts.map(
                  (account) => Card(
                    child: ListTile(
                      title: Text(account.title),
                      subtitle: Text(
                        '${_typeLabel(account.type)}'
                        '${account.branch == null ? '' : ' • ${account.branch}'}',
                      ),
                      trailing: Text(_amount(account.balance)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: Text(
            _amount(value),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
}

String _amount(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);

String _typeLabel(String value) => switch (value) {
      'Bank' => 'بانک',
      'Cash' => 'صندوق',
      'Petty Cash' => 'تنخواه',
      _ => value,
    };

String _chequeLabel(String value) {
  const labels = {
    'Incoming': 'دریافتی',
    'Outgoing': 'پرداختی',
    'Draft': 'پیش‌نویس',
    'Received': 'دریافت‌شده',
    'Deposited': 'واگذار به بانک',
    'Issued': 'صادرشده',
    'Cleared': 'وصول‌شده',
    'Returned': 'برگشتی',
    'Cancelled': 'لغوشده',
  };
  return value.split(':').map((part) => labels[part] ?? part).join(' — ');
}
