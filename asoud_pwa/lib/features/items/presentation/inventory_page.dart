import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/presentation/bloc/inventory_cubit.dart';
import 'package:asoud_pwa/features/items/presentation/inventory_setting_form.dart';
import 'package:asoud_pwa/features/items/presentation/item_management_page.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/presentation/operations_page.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum InventorySection {
  dashboard,
  movements,
  warehouses,
  itemGroups,
  units,
  items,
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({
    required this.context,
    required this.itemGateway,
    required this.operationsGateway,
    this.initialSection = InventorySection.dashboard,
    super.key,
  });

  final WorkContext context;
  final ItemGateway itemGateway;
  final OperationsGateway operationsGateway;
  final InventorySection initialSection;

  @override
  Widget build(BuildContext context) {
    if (initialSection == InventorySection.movements) {
      return OperationsPage(
        context: this.context,
        gateway: operationsGateway,
        documentTypes: const {'Stock Entry'},
      );
    }
    if (initialSection == InventorySection.items) {
      return ItemManagementPage(
        context: this.context,
        gateway: itemGateway,
      );
    }
    return BlocProvider(
      create: (_) => InventoryCubit(itemGateway, this.context)..load(),
      child: _InventoryView(section: initialSection, context: this.context),
    );
  }
}

class _InventoryView extends StatelessWidget {
  const _InventoryView({required this.section, required this.context});

  final InventorySection section;
  final WorkContext context;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          if (state.phase == InventoryPhase.initial ||
              state.phase == InventoryPhase.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.phase == InventoryPhase.failure &&
              state.workspace == const InventoryWorkspace()) {
            return _ErrorPanel(
              error: state.error ?? 'خطا در دریافت اطلاعات انبار',
              retry: context.read<InventoryCubit>().load,
            );
          }
          return Column(
            children: [
              _PageHeader(section: section, workContext: this.context),
              if (state.phase == InventoryPhase.saving)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: switch (section) {
                  InventorySection.dashboard =>
                    _Dashboard(workspace: state.workspace),
                  InventorySection.warehouses => _WarehouseSettings(
                      workspace: state.workspace,
                      save: (type, row) => _edit(context, type, row),
                    ),
                  InventorySection.itemGroups => _SimpleSettings(
                      title: 'گروه‌ها و انواع کالا',
                      subtitle:
                          'طبقه‌بندی سلسله‌مراتبی کالا و خدمت بر پایه Item Group استاندارد ERPNext',
                      rows: state.workspace.itemGroups,
                      label: (row) => row.text('item_group_name'),
                      detail: (row) => row.text('parent_item_group').isEmpty
                          ? 'ریشه ساختار'
                          : 'والد: ${row.text('parent_item_group')}',
                      canManage: state.workspace.canManage,
                      edit: (row) => _edit(context, 'Item Group', row),
                      create: () => _edit(context, 'Item Group', null),
                    ),
                  InventorySection.units => _UnitSettings(
                      workspace: state.workspace,
                      save: (type, row) => _edit(context, type, row),
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          );
        },
      );

  Future<void> _edit(
    BuildContext context,
    String type,
    InventoryRow? row,
  ) async {
    final cubit = context.read<InventoryCubit>();
    final draft = await showInventorySettingForm(
      context,
      workspace: cubit.state.workspace,
      settingType: type,
      row: row,
    );
    if (draft == null || !context.mounted) return;
    final saved = await cubit.save(draft);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'تنظیمات انبار با موفقیت ذخیره شد.'
            : 'ذخیره تنظیمات انبار انجام نشد.'),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.section, required this.workContext});

  final InventorySection section;
  final WorkContext workContext;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xffdfe5ee))),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xffedf3ff),
              child: Icon(Icons.warehouse_outlined, color: Color(0xff246bfd)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(section),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${workContext.company}${workContext.branchName == null ? '' : ' — ${workContext.branchName}'}',
                    style: const TextStyle(color: Color(0xff68758a)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  static String _title(InventorySection value) => switch (value) {
        InventorySection.dashboard => 'داشبورد انبار',
        InventorySection.warehouses => 'تنظیمات انبارها',
        InventorySection.itemGroups => 'گروه‌ها و انواع کالا',
        InventorySection.units => 'واحدهای اندازه‌گیری',
        InventorySection.items => 'کالا و خدمات',
        InventorySection.movements => 'رسید، حواله و انتقال انبار',
      };
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.workspace});

  final InventoryWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final data = workspace.dashboard;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'کالا و خدمت فعال',
              value: data.itemCount.toString(),
              detail: '${data.goodsCount} کالا — ${data.serviceCount} خدمت',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xff246bfd),
            ),
            _MetricCard(
              title: 'انبار عملیاتی',
              value: data.warehouseCount.toString(),
              detail: 'محدود به شرکت و شعبه فعال',
              icon: Icons.warehouse_outlined,
              color: const Color(0xff7c3aed),
            ),
            _MetricCard(
              title: 'اقلام دارای موجودی',
              value: data.stockedItems.toString(),
              detail: 'موجودی کل: ${_formatNumber(data.actualQty)}',
              icon: Icons.layers_outlined,
              color: const Color(0xff0f766e),
            ),
            _MetricCard(
              title: 'ارزش موجودی',
              value: _formatNumber(data.stockValue),
              detail: 'بر مبنای ارزش ثبت‌شده در Bin',
              icon: Icons.payments_outlined,
              color: const Color(0xffb45309),
            ),
            _MetricCard(
              title: 'موجودی منفی',
              value: data.negativeBins.toString(),
              detail: data.negativeBins == 0
                  ? 'بدون مغایرت منفی'
                  : 'نیازمند بررسی فوری',
              icon: Icons.warning_amber_outlined,
              color: data.negativeBins == 0
                  ? const Color(0xff15803d)
                  : const Color(0xffdc2626),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'آخرین گردش‌های انبار',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (data.recentMovements.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.inbox_outlined),
                    title: Text('هنوز گردش انباری ثبت نشده است.'),
                  ),
                for (final row in data.recentMovements)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xffedf3ff),
                      child: Text(row.docstatus == 1 ? 'ق' : 'پ'),
                    ),
                    title: Text(row.type.isEmpty ? 'عملیات انبار' : row.type),
                    subtitle: Text('${row.name} — ${row.postingDate}'),
                    trailing: Text(row.docstatus == 1 ? 'قطعی' : 'پیش‌نویس'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 244,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .1),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(color: Color(0xff68758a))),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xff68758a)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _WarehouseSettings extends StatelessWidget {
  const _WarehouseSettings({required this.workspace, required this.save});

  final InventoryWorkspace workspace;
  final Future<void> Function(String type, InventoryRow? row) save;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsHeader(
            title: 'انبارها',
            subtitle: 'ساختار درختی، شعبه، نوع انبار و حساب موجودی',
            canManage: workspace.canManage,
            actions: [
              _CreateAction(
                  'نوع انبار جدید', () => save('Warehouse Type', null)),
              _CreateAction('انبار جدید', () => save('Warehouse', null),
                  primary: true),
            ],
          ),
          _RowsCard(
            title: 'ساختار انبارها',
            rows: workspace.warehouses,
            empty: 'هنوز انباری برای شرکت فعال تعریف نشده است.',
            label: (row) => row.text('warehouse_name'),
            detail: (row) => [
              if (row.text('warehouse_type').isNotEmpty)
                row.text('warehouse_type'),
              if (row.text('branch').isNotEmpty)
                workspace.branches[row.text('branch')] ?? row.text('branch'),
              row.flag('is_group') ? 'گروهی' : 'عملیاتی',
              if (row.flag('disabled')) 'غیرفعال',
            ].join(' — '),
            edit: workspace.canManage ? (row) => save('Warehouse', row) : null,
          ),
          const SizedBox(height: 12),
          _RowsCard(
            title: 'انواع انبار',
            rows: workspace.warehouseTypes,
            empty: 'نوع انبار تعریف نشده است.',
            label: (row) => row.text('name'),
            detail: (row) => row.text('description'),
            edit: workspace.canManage
                ? (row) => save('Warehouse Type', row)
                : null,
          ),
        ],
      );
}

class _UnitSettings extends StatelessWidget {
  const _UnitSettings({required this.workspace, required this.save});

  final InventoryWorkspace workspace;
  final Future<void> Function(String type, InventoryRow? row) save;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsHeader(
            title: 'واحدهای اندازه‌گیری و تبدیل',
            subtitle: 'UOM، دسته واحد و ضریب تبدیل استاندارد ERPNext',
            canManage: workspace.canManage,
            actions: [
              _CreateAction('دسته جدید', () => save('UOM Category', null)),
              _CreateAction(
                  'ضریب تبدیل', () => save('UOM Conversion Factor', null)),
              _CreateAction('واحد جدید', () => save('UOM', null),
                  primary: true),
            ],
          ),
          _RowsCard(
            title: 'واحدهای اندازه‌گیری',
            rows: workspace.uoms,
            empty: 'واحد اندازه‌گیری تعریف نشده است.',
            label: (row) => row.text('uom_name'),
            detail: (row) =>
                '${row.flag('enabled') ? 'فعال' : 'غیرفعال'}${row.flag('must_be_whole_number') ? ' — فقط عدد صحیح' : ''}',
            edit: workspace.canManage ? (row) => save('UOM', row) : null,
          ),
          const SizedBox(height: 12),
          _RowsCard(
            title: 'دسته‌های واحد',
            rows: workspace.uomCategories,
            empty: 'دسته واحد تعریف نشده است.',
            label: (row) => row.text('category_name'),
            detail: (_) => 'مبنای گروه‌بندی تبدیل‌ها',
          ),
          const SizedBox(height: 12),
          _RowsCard(
            title: 'ضرایب تبدیل',
            rows: workspace.uomConversions,
            empty: 'ضریب تبدیلی تعریف نشده است.',
            label: (row) => '${row.text('from_uom')} ← ${row.text('to_uom')}',
            detail: (row) =>
                '${row.text('category')} — ضریب ${row.number('value')}',
            edit: workspace.canManage
                ? (row) => save('UOM Conversion Factor', row)
                : null,
          ),
        ],
      );
}

class _SimpleSettings extends StatelessWidget {
  const _SimpleSettings({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.label,
    required this.detail,
    required this.canManage,
    required this.edit,
    required this.create,
  });

  final String title;
  final String subtitle;
  final List<InventoryRow> rows;
  final String Function(InventoryRow) label;
  final String Function(InventoryRow) detail;
  final bool canManage;
  final ValueChanged<InventoryRow> edit;
  final VoidCallback create;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsHeader(
            title: title,
            subtitle: subtitle,
            canManage: canManage,
            actions: [_CreateAction('گروه جدید', create, primary: true)],
          ),
          _RowsCard(
            title: title,
            rows: rows,
            empty: 'موردی تعریف نشده است.',
            label: label,
            detail: detail,
            edit: canManage ? edit : null,
          ),
        ],
      );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.title,
    required this.subtitle,
    required this.canManage,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final bool canManage;
  final List<_CreateAction> actions;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, color: Color(0xff246bfd)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0xff68758a))),
                  ],
                ),
              ),
              if (!canManage)
                const Chip(label: Text('فقط مشاهده'))
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final action in actions)
                      action.primary
                          ? FilledButton.icon(
                              onPressed: action.action,
                              icon: const Icon(Icons.add),
                              label: Text(action.label),
                            )
                          : OutlinedButton.icon(
                              onPressed: action.action,
                              icon: const Icon(Icons.add),
                              label: Text(action.label),
                            ),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _CreateAction {
  const _CreateAction(this.label, this.action, {this.primary = false});
  final String label;
  final VoidCallback action;
  final bool primary;
}

class _RowsCard extends StatelessWidget {
  const _RowsCard({
    required this.title,
    required this.rows,
    required this.empty,
    required this.label,
    required this.detail,
    this.edit,
  });

  final String title;
  final List<InventoryRow> rows;
  final String empty;
  final String Function(InventoryRow) label;
  final String Function(InventoryRow) detail;
  final ValueChanged<InventoryRow>? edit;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Divider(height: 24),
              if (rows.isEmpty) ListTile(title: Text(empty)),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffedf3ff),
                    child: Icon(Icons.inventory_2_outlined,
                        color: Color(0xff246bfd)),
                  ),
                  title: Text(label(row)),
                  subtitle: Text(detail(row)),
                  trailing: edit == null
                      ? null
                      : IconButton(
                          tooltip: 'ویرایش',
                          onPressed: () => edit!(row),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                ),
            ],
          ),
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.retry});
  final String error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(height: 10),
                Text(error),
                const SizedBox(height: 10),
                OutlinedButton(
                    onPressed: retry, child: const Text('تلاش دوباره')),
              ],
            ),
          ),
        ),
      );
}

String _formatNumber(num value) {
  final text = value.round().toString();
  final output = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) output.write(',');
    output.write(text[index]);
  }
  return output.toString();
}
