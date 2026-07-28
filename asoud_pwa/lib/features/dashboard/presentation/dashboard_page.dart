import 'dart:math' as math;

import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_gateway.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_models.dart';
import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/presentation/operation_form.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';

class DashboardController extends ChangeNotifier {
  bool quickAccessOpen = false;
  bool quickCreateOpen = false;
  bool notificationsOpen = false;
  String? preferredDocumentType;
  VoidCallback? _refresh;

  void bindRefresh(VoidCallback refresh) => _refresh = refresh;

  void unbindRefresh(VoidCallback refresh) {
    if (_refresh == refresh) _refresh = null;
  }

  void refresh() => _refresh?.call();

  void toggleQuickAccess() {
    quickAccessOpen = !quickAccessOpen;
    if (quickAccessOpen) quickCreateOpen = false;
    notifyListeners();
  }

  void toggleQuickCreate() {
    quickCreateOpen = !quickCreateOpen;
    if (quickCreateOpen) quickAccessOpen = false;
    notifyListeners();
  }

  void showQuickCreate([String? documentType]) {
    preferredDocumentType = documentType;
    quickCreateOpen = true;
    quickAccessOpen = false;
    notifyListeners();
  }

  void toggleNotifications() {
    notificationsOpen = !notificationsOpen;
    notifyListeners();
  }

  void closeOverlays() {
    quickAccessOpen = false;
    quickCreateOpen = false;
    notificationsOpen = false;
    notifyListeners();
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.context,
    required this.gateway,
    required this.operationsGateway,
    required this.controller,
    required this.openModule,
    required this.openApprovals,
    super.key,
  });

  final WorkContext context;
  final DashboardGateway gateway;
  final OperationsGateway operationsGateway;
  final DashboardController controller;
  final ValueChanged<int> openModule;
  final VoidCallback openApprovals;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardSnapshot> data = widget.gateway.load(widget.context);

  @override
  void initState() {
    super.initState();
    widget.controller.bindRefresh(_refresh);
  }

  @override
  void dispose() {
    widget.controller.unbindRefresh(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => data = widget.gateway.load(widget.context));
    await data;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardSnapshot>(
        future: data,
        builder: (context, state) {
          if (state.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.hasError) {
            return _DashboardError(error: state.error, retry: _refresh);
          }
          final snapshot = state.requireData;
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: widget.controller.notificationsOpen
                        ? widget.controller.closeOverlays
                        : null,
                    child: _DashboardBody(
                      workContext: widget.context,
                      snapshot: snapshot,
                      refresh: _refresh,
                      openOperations: () => widget.openModule(3),
                      openApprovals: widget.openApprovals,
                    ),
                  ),
                ),
                if (widget.controller.quickAccessOpen)
                  Positioned(
                    top: 8,
                    bottom: 8,
                    right: 8,
                    width: 300,
                    child: _QuickAccessDrawer(
                      close: widget.controller.toggleQuickAccess,
                      openModule: widget.openModule,
                    ),
                  ),
                if (widget.controller.quickCreateOpen)
                  Positioned(
                    top: 8,
                    bottom: 8,
                    left: 8,
                    width: 350,
                    child: _QuickCreateDrawer(
                      context: widget.context,
                      contracts: snapshot.quickCreateContracts,
                      initialDocumentType:
                          widget.controller.preferredDocumentType,
                      gateway: widget.operationsGateway,
                      close: widget.controller.toggleQuickCreate,
                      saved: _refresh,
                    ),
                  ),
                if (widget.controller.notificationsOpen)
                  Positioned(
                    top: 8,
                    left: 72,
                    width: 390,
                    child: _NotificationPopover(
                      items: snapshot.notifications,
                      close: widget.controller.toggleNotifications,
                      markRead: (item) async {
                        if (!item.read) {
                          await widget.gateway.markNotificationRead(item.name);
                          await _refresh();
                        }
                      },
                      openTarget: (item) {
                        widget.controller.closeOverlays();
                        widget
                            .openModule(_moduleForDocument(item.documentType));
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.workContext,
    required this.snapshot,
    required this.refresh,
    required this.openOperations,
    required this.openApprovals,
  });

  final WorkContext workContext;
  final DashboardSnapshot snapshot;
  final Future<void> Function() refresh;
  final VoidCallback openOperations;
  final VoidCallback openApprovals;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_outlined,
                        size: 20, color: AsoudColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'داشبورد مدیریتی',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AsoudColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      workContext.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AsoudColors.muted),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'به‌روزرسانی: ${_faDate(snapshot.generatedAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AsoudColors.muted),
                    ),
                    IconButton(
                      tooltip: 'به‌روزرسانی',
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1450
                    ? 6
                    : constraints.maxWidth >= 950
                        ? 3
                        : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final definition in _metricDefinitions)
                      SizedBox(
                        width: width,
                        child: _MetricCard(
                          definition: definition,
                          metric: snapshot.metric(definition.key),
                          currency: snapshot.currency,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1000;
                final chart = _Panel(
                  title: 'جریان نقدی ماهانه',
                  subtitle: 'دریافت و پرداخت شش ماه اخیر',
                  child: SizedBox(
                    height: 255,
                    child: _CashFlowChart(points: snapshot.cashFlow),
                  ),
                );
                final mix = _Panel(
                  title: 'ترکیب درآمد',
                  subtitle: 'از ابتدای ماه تا امروز',
                  child: SizedBox(
                    height: 255,
                    child: _IncomeMixChart(slices: snapshot.incomeMix),
                  ),
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: chart),
                          const SizedBox(width: 12),
                          Expanded(child: mix),
                        ],
                      )
                    : Column(
                        children: [chart, const SizedBox(height: 12), mix],
                      );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1050;
                final operations = _Panel(
                  title: 'آخرین عملیات',
                  action: TextButton.icon(
                    onPressed: openOperations,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('مشاهده همه'),
                  ),
                  child: _RecentOperations(
                    items: snapshot.recentOperations,
                    currency: snapshot.currency,
                  ),
                );
                final approvals = _Panel(
                  title: 'کارتابل من',
                  subtitle:
                      '${_faNumber(snapshot.incomingApprovalCount)} درخواست در انتظار',
                  child: _ApprovalInbox(
                    items: snapshot.approvals,
                    open: openApprovals,
                  ),
                );
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: operations),
                          const SizedBox(width: 12),
                          Expanded(child: approvals),
                        ],
                      )
                    : Column(
                        children: [
                          operations,
                          const SizedBox(height: 12),
                          approvals,
                        ],
                      );
              },
            ),
          ],
        ),
      );
}

class _MetricDefinition {
  const _MetricDefinition(this.key, this.title, this.icon, this.color);

  final String key;
  final String title;
  final IconData icon;
  final Color color;
}

const _metricDefinitions = [
  _MetricDefinition('sales_today', 'فروش امروز', Icons.shopping_cart_outlined,
      Color(0xff155bd7)),
  _MetricDefinition(
      'receipts_today', 'دریافت امروز', Icons.south_west, AsoudColors.success),
  _MetricDefinition(
      'payments_today', 'پرداخت امروز', Icons.north_east, AsoudColors.danger),
  _MetricDefinition('bank_balance', 'مانده بانک',
      Icons.account_balance_outlined, Color(0xff7557c8)),
  _MetricDefinition('cash_balance', 'مانده صندوق', Icons.payments_outlined,
      AsoudColors.warning),
  _MetricDefinition('petty_cash_balance', 'مانده تنخواه', Icons.wallet_outlined,
      AsoudColors.cyan),
];

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.definition,
    required this.metric,
    required this.currency,
  });

  final _MetricDefinition definition;
  final DashboardMetric metric;
  final String currency;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      definition.title,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AsoudColors.muted),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: definition.color.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(definition.icon,
                          color: definition.color, size: 21),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                _money(metric.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AsoudColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    currency.isEmpty ? 'ریال' : currency,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AsoudColors.muted),
                  ),
                  const Spacer(),
                  if (metric.trend != null) ...[
                    Icon(
                      metric.trend! >= 0
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      color: metric.trend! >= 0
                          ? AsoudColors.success
                          : AsoudColors.danger,
                      size: 18,
                    ),
                    Text(
                      '${_faNumber(metric.trend!.abs())}٪',
                      style: TextStyle(
                        color: metric.trend! >= 0
                            ? AsoudColors.success
                            : AsoudColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AsoudColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AsoudColors.muted),
                          ),
                      ],
                    ),
                  ),
                  if (action != null)
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                            color: AsoudColors.primary,
                          ),
                      child: action!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({required this.points});

  final List<CashFlowPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyState(label: 'داده‌ای ثبت نشده است.');
    }
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _Legend(color: AsoudColors.success, label: 'دریافت'),
            SizedBox(width: 16),
            _Legend(color: AsoudColors.danger, label: 'پرداخت'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CustomPaint(
            painter: _CashFlowPainter(points),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _CashFlowPainter extends CustomPainter {
  const _CashFlowPainter(this.points);

  final List<CashFlowPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final labelHeight = 28.0;
    final chartHeight = size.height - labelHeight;
    final maxValue = points.fold<double>(
      1,
      (maxValue, point) =>
          math.max(maxValue, math.max(point.receipts, point.payments)),
    );
    final grid = Paint()
      ..color = AsoudColors.border
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = chartHeight * index / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final slot = size.width / points.length;
    final barWidth = math.min(slot * .18, 18.0);
    final receiptPaint = Paint()..color = AsoudColors.success;
    final paymentPaint = Paint()..color = AsoudColors.danger;
    final balancePaint = Paint()
      ..color = AsoudColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final center = slot * index + slot / 2;
      final receiptHeight = chartHeight * .82 * point.receipts / maxValue;
      final paymentHeight = chartHeight * .82 * point.payments / maxValue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center - barWidth - 2,
            chartHeight - receiptHeight,
            barWidth,
            receiptHeight,
          ),
          const Radius.circular(3),
        ),
        receiptPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center + 2,
            chartHeight - paymentHeight,
            barWidth,
            paymentHeight,
          ),
          const Radius.circular(3),
        ),
        paymentPaint,
      );
      final balance = point.receipts - point.payments;
      final balanceY = chartHeight -
          (chartHeight * .42) -
          (balance / maxValue * chartHeight * .35);
      if (index == 0) {
        path.moveTo(center, balanceY);
      } else {
        path.lineTo(center, balanceY);
      }
      final painter = TextPainter(
        text: TextSpan(
          text: _faDate(point.period),
          style: const TextStyle(fontSize: 10, color: AsoudColors.muted),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: slot);
      painter.paint(
        canvas,
        Offset(center - painter.width / 2, chartHeight + 7),
      );
    }
    canvas.drawPath(path, balancePaint);
  }

  @override
  bool shouldRepaint(covariant _CashFlowPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _IncomeMixChart extends StatelessWidget {
  const _IncomeMixChart({required this.slices});

  final List<IncomeSlice> slices;

  @override
  Widget build(BuildContext context) {
    final effective = slices.isEmpty
        ? const [
            IncomeSlice(category: 'goods', amount: 0),
            IncomeSlice(category: 'services', amount: 0),
          ]
        : slices;
    final total = effective.fold<double>(0, (sum, item) => sum + item.amount);
    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _DonutPainter(effective),
                child: const SizedBox.square(dimension: 170),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('کل درآمد',
                      style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
                  Text(
                    _compactMoney(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AsoudColors.navy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < effective.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: _Legend(
                    color: _sliceColors[index % _sliceColors.length],
                    label:
                        '${_categoryLabel(effective[index].category)}  ${total == 0 ? '۰' : _faNumber((effective[index].amount / total * 100).round())}٪',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

const _sliceColors = [
  AsoudColors.primary,
  AsoudColors.success,
  AsoudColors.warning,
  AsoudColors.danger,
];

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.slices);

  final List<IncomeSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final total = slices.fold<double>(0, (sum, item) => sum + item.amount);
    var start = -math.pi / 2;
    if (total <= 0) {
      canvas.drawArc(
        rect.deflate(18),
        start,
        math.pi * 2,
        false,
        Paint()
          ..color = AsoudColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      return;
    }
    for (var index = 0; index < slices.length; index++) {
      final sweep = math.pi * 2 * slices[index].amount / total;
      canvas.drawArc(
        rect.deflate(18),
        start,
        math.max(0, sweep - .025),
        false,
        Paint()
          ..color = _sliceColors[index % _sliceColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const SizedBox.square(dimension: 9),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
            ),
          ),
        ],
      );
}

class _RecentOperations extends StatelessWidget {
  const _RecentOperations({required this.items, required this.currency});

  final List<OperationalDocument> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 205,
        child: _EmptyState(label: 'عملیاتی در این محدوده ثبت نشده است.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 48,
        columns: const [
          DataColumn(label: Text('نوع عملیات')),
          DataColumn(label: Text('شماره سند')),
          DataColumn(label: Text('تاریخ')),
          DataColumn(label: Text('مبلغ')),
          DataColumn(label: Text('وضعیت')),
        ],
        rows: [
          for (final item in items)
            DataRow(
              cells: [
                DataCell(Text(_documentLabel(item.documentType))),
                DataCell(Text(item.name)),
                DataCell(Text(_faDate(item.postingDate ?? '-'))),
                DataCell(Text(
                  item.amount == null
                      ? '-'
                      : '${_money(item.amount!)} ${currency.isEmpty ? 'ریال' : currency}',
                )),
                DataCell(_StatusPill(
                  text: item.docstatus == 1
                      ? 'ثبت‌شده'
                      : item.docstatus == 2
                          ? 'ابطال‌شده'
                          : item.approvalStatus == 'Pending'
                              ? 'در انتظار تأیید'
                              : 'پیش‌نویس',
                  color: item.docstatus == 1
                      ? AsoudColors.success
                      : item.docstatus == 2
                          ? AsoudColors.danger
                          : AsoudColors.warning,
                )),
              ],
            ),
        ],
      ),
    );
  }
}

class _ApprovalInbox extends StatelessWidget {
  const _ApprovalInbox({required this.items, required this.open});

  final List<DashboardApproval> items;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 205,
        child: _EmptyState(label: 'درخواست تأیید جدیدی وجود ندارد.'),
      );
    }
    return Column(
      children: [
        for (final item in items)
          ListTile(
            onTap: open,
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xfffff3dd),
              child: Icon(Icons.pending_actions,
                  size: 17, color: AsoudColors.warning),
            ),
            title: Text(
              '${_documentLabel(item.sourceType)} ${item.sourceName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.requestedBy,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_left, size: 18),
          ),
      ],
    );
  }
}

class _QuickAccessDrawer extends StatelessWidget {
  const _QuickAccessDrawer({
    required this.close,
    required this.openModule,
  });

  final VoidCallback close;
  final ValueChanged<int> openModule;

  void _open(int module) {
    close();
    openModule(module);
  }

  @override
  Widget build(BuildContext context) => Material(
        elevation: 12,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _DrawerHeader(title: 'دسترسی سریع', close: close),
            const _DrawerSectionLabel('داشبوردها'),
            _AccessItem(
                icon: Icons.speed_outlined,
                title: 'داشبورد مدیریتی',
                selected: true,
                onTap: () => _open(0)),
            _AccessItem(
                icon: Icons.bar_chart_outlined,
                title: 'داشبورد مالی',
                onTap: () => _open(1)),
            _AccessItem(
                icon: Icons.apartment_outlined,
                title: 'داشبورد شعب',
                onTap: () => _open(8)),
            _AccessItem(
                icon: Icons.groups_2_outlined,
                title: 'داشبورد منابع انسانی',
                onTap: () => _open(6)),
            const Divider(),
            const _DrawerSectionLabel('نماهای ذخیره‌شده'),
            _SavedView(title: 'گزارش فروش ماهانه', onTap: () => _open(7)),
            _SavedView(title: 'وضعیت دریافت‌ها', onTap: () => _open(2)),
            _SavedView(title: 'تحلیل موجودی انبار', onTap: () => _open(5)),
            _SavedView(title: 'عملکرد پرسنل', onTap: () => _open(6)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _open(8),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('مدیریت نماهای ذخیره‌شده'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
}

class _QuickCreateDrawer extends StatefulWidget {
  const _QuickCreateDrawer({
    required this.context,
    required this.contracts,
    required this.gateway,
    required this.close,
    required this.saved,
    this.initialDocumentType,
  });

  final WorkContext context;
  final List<OperationContract> contracts;
  final OperationsGateway gateway;
  final VoidCallback close;
  final Future<void> Function() saved;
  final String? initialDocumentType;

  @override
  State<_QuickCreateDrawer> createState() => _QuickCreateDrawerState();
}

class _QuickCreateDrawerState extends State<_QuickCreateDrawer> {
  OperationContract? selected;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.contracts.isNotEmpty) {
      selected = widget.contracts
          .where(
            (item) => item.documentType == widget.initialDocumentType,
          )
          .firstOrNull;
      selected ??= widget.contracts.first;
    }
  }

  Future<void> _continue() async {
    if (selected == null || saving) return;
    final payload = await showOperationForm(
      context,
      contract: selected!,
      gateway: widget.gateway,
    );
    if (payload == null || !mounted) return;
    setState(() => saving = true);
    try {
      final name = await widget.gateway.createDraft(
        context: widget.context,
        documentType: selected!.documentType,
        payload: payload,
      );
      await widget.saved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('پیش‌نویس $name با موفقیت ثبت شد.')),
        );
        widget.close();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
        elevation: 12,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(title: 'ایجاد سریع', close: widget.close),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<OperationContract>(
                      value: selected,
                      decoration: const InputDecoration(
                        labelText: 'نوع عملیات',
                        prefixIcon: Icon(Icons.add_box_outlined),
                      ),
                      items: [
                        for (final contract in widget.contracts)
                          DropdownMenuItem(
                            value: contract,
                            child: Text(_documentLabel(contract.documentType)),
                          ),
                      ],
                      onChanged: (value) => setState(() => selected = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: widget.context.company,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'شرکت',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue:
                          widget.context.branchName ?? 'تمام شعب مجاز',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'شعبه',
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfff4f7fd),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'فیلدهای فرم بر اساس قرارداد واقعی سند نمایش داده می‌شوند و پیش‌نویس با کلید یکتای امن ثبت خواهد شد.',
                        style:
                            TextStyle(fontSize: 12, color: AsoudColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: FilledButton.icon(
                onPressed: saving ? null : _continue,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description_outlined),
                label: const Text('تکمیل و ثبت پیش‌نویس'),
              ),
            ),
          ],
        ),
      );
}

class _NotificationPopover extends StatelessWidget {
  const _NotificationPopover({
    required this.items,
    required this.close,
    required this.markRead,
    required this.openTarget,
  });

  final List<DashboardNotification> items;
  final VoidCallback close;
  final Future<void> Function(DashboardNotification item) markRead;
  final ValueChanged<DashboardNotification> openTarget;

  @override
  Widget build(BuildContext context) => Material(
        elevation: 16,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DrawerHeader(title: 'اعلان‌ها', close: close),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text('اعلان جدیدی وجود ندارد.'),
              )
            else
              for (final item in items)
                ListTile(
                  onTap: () async {
                    await markRead(item);
                    openTarget(item);
                  },
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: item.read
                        ? const Color(0xffeef1f5)
                        : const Color(0xffe9f1ff),
                    child: Icon(
                      item.read
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                      size: 17,
                      color:
                          item.read ? AsoudColors.muted : AsoudColors.primary,
                    ),
                  ),
                  title: Text(
                    item.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_faDate(item.creation)),
                ),
            TextButton(
              onPressed: () async {
                for (final item in items.where((item) => !item.read)) {
                  await markRead(item);
                }
                close();
              },
              child: const Text('خواندن همه اعلان‌ها'),
            ),
          ],
        ),
      );
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.close});

  final String title;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AsoudColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AsoudColors.navy,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'بستن',
              onPressed: close,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      );
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AsoudColors.muted),
          ),
        ),
      );
}

class _AccessItem extends StatelessWidget {
  const _AccessItem({
    required this.icon,
    required this.title,
    this.selected = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: ListTile(
          onTap: onTap,
          dense: true,
          selected: selected,
          selectedColor: AsoudColors.primary,
          selectedTileColor: const Color(0xffedf3ff),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: selected
                ? const BorderSide(color: Color(0xff9ebeff))
                : BorderSide.none,
          ),
          leading: Icon(icon, size: 20),
          title: Text(title),
        ),
      );
}

class _SavedView extends StatelessWidget {
  const _SavedView({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        dense: true,
        leading: const Icon(Icons.star_border, size: 18),
        title: Text(title),
        trailing: const Icon(Icons.more_horiz, size: 18),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                color: AsoudColors.muted, size: 34),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AsoudColors.muted)),
          ],
        ),
      );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.retry});

  final Object? error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AsoudColors.danger, size: 42),
            const SizedBox(height: 10),
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

String _documentLabel(String value) =>
    const {
      'Sales Invoice': 'فاکتور فروش',
      'Purchase Invoice': 'فاکتور خرید',
      'Payment Entry': 'دریافت/پرداخت',
      'Stock Entry': 'عملیات انبار',
      'Journal Entry': 'سند حسابداری',
      'ASOUD Treasury Transaction': 'عملیات خزانه',
      'ASOUD Cheque': 'چک',
      'ASOUD Intercompany Transfer': 'انتقال بین‌شرکتی',
      'ASOUD Daily Work Report': 'گزارش کار روزانه',
      'ASOUD Internal Communication': 'مکاتبه داخلی',
    }[value] ??
    value;

int _moduleForDocument(String? value) => switch (value) {
      'Journal Entry' => 1,
      'Payment Entry' || 'ASOUD Treasury Transaction' || 'ASOUD Cheque' => 2,
      'Sales Invoice' => 3,
      'Purchase Invoice' => 4,
      'Stock Entry' => 5,
      'Employee' ||
      'ASOUD Daily Work Report' ||
      'ASOUD Internal Communication' =>
        6,
      _ => 0,
    };

String _categoryLabel(String value) =>
    const {
      'goods': 'فروش کالا',
      'services': 'خدمات',
      'other': 'سایر درآمدها',
      'discounts': 'تخفیف و مرجوعی',
    }[value] ??
    value;

String _money(double value) =>
    _faDigits(value.round().toString().replaceAllMapped(
          RegExp(r'(?=(\d{3})+(?!\d))'),
          (_) => '٬',
        ));

String _compactMoney(double value) {
  if (value.abs() >= 1000000000) {
    return '${_faNumber((value / 1000000000).toStringAsFixed(1))} میلیارد';
  }
  if (value.abs() >= 1000000) {
    return '${_faNumber((value / 1000000).toStringAsFixed(1))} میلیون';
  }
  return _money(value);
}

String _faDate(String value) => _faDigits(
      value.length > 16 ? value.substring(0, 16) : value,
    );

String _faNumber(Object value) => _faDigits(value.toString());

String _faDigits(String value) {
  const western = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = value;
  for (var index = 0; index < western.length; index++) {
    result = result.replaceAll(western[index], persian[index]);
  }
  return result;
}
