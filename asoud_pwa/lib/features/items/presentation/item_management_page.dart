import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/items/presentation/bloc/item_management_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ItemManagementPage extends StatelessWidget {
  const ItemManagementPage({
    required this.context,
    required this.gateway,
    super.key,
  });

  final WorkContext context;
  final ItemGateway gateway;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ItemManagementCubit(gateway, this.context)..load(),
        child: const _ItemManagementView(),
      );
}

class _ItemManagementView extends StatefulWidget {
  const _ItemManagementView();

  @override
  State<_ItemManagementView> createState() => _ItemManagementViewState();
}

class _ItemManagementViewState extends State<_ItemManagementView> {
  String? kindFilter;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ItemManagementCubit, ItemManagementState>(
        builder: (context, state) {
          final cubit = context.read<ItemManagementCubit>();
          final items = state.snapshot.items
              .where((item) => kindFilter == null || item.kind == kindFilter)
              .toList(growable: false);
          return Stack(
            children: [
              ColoredBox(
                color: const Color(0xfff5f7fb),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DirectoryHeader(create: cubit.create),
                      const SizedBox(height: 16),
                      _FilterBar(
                        selected: kindFilter,
                        search: (value) => cubit.load(search: value),
                        select: (value) => setState(() => kindFilter = value),
                        goodsCount: state.snapshot.items
                            .where((item) => item.kind == 'Goods')
                            .length,
                        serviceCount: state.snapshot.items
                            .where((item) => item.kind == 'Service')
                            .length,
                      ),
                      const SizedBox(height: 16),
                      if (state.phase == ItemPhase.loading)
                        const LinearProgressIndicator(minHeight: 2),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Expanded(
                        child: _ItemTable(items: items, edit: cubit.edit),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.draft != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: cubit.cancel,
                    child: Container(color: const Color(0x3312213d)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ItemDrawer(
                    draft: state.draft!,
                    options: state.snapshot.options,
                    saving: state.phase == ItemPhase.saving,
                    cubit: cubit,
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({required this.create});

  final VoidCallback create;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کالا و خدمات',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'هویت مشترک در هلدینگ و سیاست عملیاتی مستقل برای شرکت فعال',
                  style: TextStyle(color: AsoudColors.muted),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: create,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('ایجاد کالا یا خدمت'),
          ),
        ],
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.search,
    required this.select,
    required this.goodsCount,
    required this.serviceCount,
  });

  final String? selected;
  final ValueChanged<String> search;
  final ValueChanged<String?> select;
  final int goodsCount;
  final int serviceCount;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'نام یا کد کالا و خدمت...',
                  ),
                  onSubmitted: search,
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'همه',
                count: goodsCount + serviceCount,
                selected: selected == null,
                tap: () => select(null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'کالا',
                count: goodsCount,
                selected: selected == 'Goods',
                tap: () => select('Goods'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'خدمت',
                count: serviceCount,
                selected: selected == 'Service',
                tap: () => select('Service'),
              ),
              const Spacer(),
              const Icon(Icons.info_outline,
                  size: 18, color: AsoudColors.muted),
              const SizedBox(width: 6),
              const Text(
                'کد هنگام ثبت قطعی ایجاد می‌شود',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted),
              ),
            ],
          ),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.tap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback tap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AsoudColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AsoudColors.primary : AsoudColors.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AsoudColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white70 : AsoudColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ItemTable extends StatelessWidget {
  const _ItemTable({required this.items, required this.edit});

  final List<ItemSummary> items;
  final ValueChanged<String> edit;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: items.isEmpty
            ? const Center(
                child: Text(
                  'هنوز کالا یا خدمتی برای شرکت فعال تعریف نشده است.',
                  style: TextStyle(color: AsoudColors.muted),
                ),
              )
            : SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xfff7f9fc)),
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('کالا / خدمت')),
                      DataColumn(label: Text('کد')),
                      DataColumn(label: Text('نوع')),
                      DataColumn(label: Text('گروه')),
                      DataColumn(label: Text('واحد')),
                      DataColumn(label: Text('وضعیت شرکت')),
                    ],
                    rows: [
                      for (final item in items)
                        DataRow(
                          onSelectChanged: (_) => edit(item.code),
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: item.kind == 'Goods'
                                        ? const Color(0xffedf3ff)
                                        : const Color(0xffeaf8f8),
                                    child: Icon(
                                      item.kind == 'Goods'
                                          ? Icons.inventory_2_outlined
                                          : Icons.design_services_outlined,
                                      size: 18,
                                      color: item.kind == 'Goods'
                                          ? AsoudColors.primary
                                          : const Color(0xff148b8c),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(item.code)),
                            DataCell(_KindBadge(kind: item.kind)),
                            DataCell(Text(item.group)),
                            DataCell(Text(item.uom)),
                            DataCell(_StatusBadge(enabled: item.enabled)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      );
}

class _ItemDrawer extends StatelessWidget {
  const _ItemDrawer({
    required this.draft,
    required this.options,
    required this.saving,
    required this.cubit,
  });

  final ItemDraft draft;
  final ItemOptions options;
  final bool saving;
  final ItemManagementCubit cubit;

  @override
  Widget build(BuildContext context) => Material(
        elevation: 18,
        color: Colors.white,
        child: SizedBox(
          width: 620,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            draft.itemCode == null
                                ? 'ایجاد کالا یا خدمت'
                                : 'ویرایش ${draft.itemCode}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            draft.itemCode == null
                                ? 'کد پس از ثبت و بر اساس نوع به‌صورت خودکار ساخته می‌شود.'
                                : 'هویت مشترک و سیاست شرکت فعال را کنترل کنید.',
                            style: const TextStyle(
                                fontSize: 11, color: AsoudColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: cubit.cancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _DrawerSection(
                        number: '۱',
                        title: 'اطلاعات پایه',
                        child: Column(
                          children: [
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'Goods',
                                  label: Text('کالا'),
                                  icon: Icon(Icons.inventory_2_outlined),
                                ),
                                ButtonSegment(
                                  value: 'Service',
                                  label: Text('خدمت'),
                                  icon: Icon(Icons.design_services_outlined),
                                ),
                              ],
                              selected: {draft.itemKind},
                              onSelectionChanged: (value) => cubit.update(
                                draft.copyWith(itemKind: value.first),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: draft.itemName,
                              decoration:
                                  const InputDecoration(labelText: 'نام *'),
                              onChanged: (value) =>
                                  cubit.update(draft.copyWith(itemName: value)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _select(
                                    'گروه *',
                                    draft.itemGroup,
                                    options.itemGroups,
                                    (value) => cubit.update(
                                        draft.copyWith(itemGroup: value)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _select(
                                    'واحد سنجش *',
                                    draft.stockUom,
                                    options.uoms,
                                    (value) => cubit.update(
                                        draft.copyWith(stockUom: value)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: draft.description,
                              minLines: 2,
                              maxLines: 3,
                              decoration:
                                  const InputDecoration(labelText: 'شرح'),
                              onChanged: (value) => cubit
                                  .update(draft.copyWith(description: value)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DrawerSection(
                        number: '۲',
                        title: 'سیاست شرکت فعال',
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('فعال در شرکت جاری'),
                              subtitle: const Text(
                                  'این وضعیت روی شرکت‌های دیگر اثری ندارد.'),
                              value: draft.enabled,
                              onChanged: (value) =>
                                  cubit.update(draft.copyWith(enabled: value)),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _select(
                                    'شعبه پیش‌فرض',
                                    draft.defaultBranch,
                                    options.branches,
                                    (value) => cubit.update(
                                        draft.copyWith(defaultBranch: value)),
                                  ),
                                ),
                                if (draft.itemKind == 'Goods') ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _select(
                                      'انبار پیش‌فرض',
                                      draft.defaultWarehouse,
                                      options.warehouses,
                                      (value) => cubit.update(draft.copyWith(
                                          defaultWarehouse: value)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _select(
                                    'حساب درآمد',
                                    draft.incomeAccount,
                                    options.incomeAccounts,
                                    (value) => cubit.update(
                                        draft.copyWith(incomeAccount: value)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _select(
                                    'حساب هزینه',
                                    draft.expenseAccount,
                                    options.expenseAccounts,
                                    (value) => cubit.update(
                                        draft.copyWith(expenseAccount: value)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DrawerSection(
                        number: '۳',
                        title: 'وضعیت هویت مشترک',
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('غیرفعال در کل هلدینگ'),
                          subtitle: const Text(
                            'فقط برای توقف استفاده در همه شرکت‌ها فعال شود.',
                          ),
                          value: draft.disabled,
                          onChanged: (value) =>
                              cubit.update(draft.copyWith(disabled: value)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xfffbfcfe),
                  border: Border(top: BorderSide(color: AsoudColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: saving ? null : cubit.save,
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('ثبت کالا یا خدمت'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: saving ? null : cubit.cancel,
                      child: const Text('انصراف'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _select(
    String label,
    String value,
    List<String> rows,
    ValueChanged<String> changed,
  ) {
    final values = {if (value.isNotEmpty) value, ...rows}.toList();
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('انتخاب نشده')),
        for (final row in values)
          DropdownMenuItem(value: row, child: Text(row)),
      ],
      onChanged: (item) => changed(item ?? ''),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xffedf3ff),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: AsoudColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const Divider(height: 22),
            child,
          ],
        ),
      );
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final goods = kind == 'Goods';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: goods ? const Color(0xffedf3ff) : const Color(0xffeaf8f8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        goods ? 'کالا' : 'خدمت',
        style: TextStyle(
          color: goods ? AsoudColors.primary : const Color(0xff148b8c),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xffe8f8f0) : const Color(0xfffff0f0),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          enabled ? 'فعال' : 'غیرفعال',
          style: TextStyle(
            color: enabled ? const Color(0xff16a364) : const Color(0xffdc3545),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
