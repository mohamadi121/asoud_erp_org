import 'package:asoud_pwa/core/theme/asoud_theme.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/items/presentation/bloc/item_management_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ItemManagementPage extends StatelessWidget {
  const ItemManagementPage(
      {required this.context, required this.gateway, super.key});
  final WorkContext context;
  final ItemGateway gateway;
  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (_) => ItemManagementCubit(gateway, this.context)..load(),
      child: const _ItemView());
}

class _ItemView extends StatelessWidget {
  const _ItemView();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ItemManagementCubit, ItemManagementState>(
          builder: (context, state) {
        final cubit = context.read<ItemManagementCubit>();
        if (state.draft != null) {
          return _ItemForm(
              draft: state.draft!,
              options: state.snapshot.options,
              cubit: cubit);
        }
        return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('کالا و خدمات',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const Text(
                              'تعریف مشترک در هلدینگ و تنظیم مستقل برای شرکت فعال',
                              style: TextStyle(color: AsoudColors.muted)),
                        ])),
                    FilledButton.icon(
                        onPressed: cubit.create,
                        icon: const Icon(Icons.add),
                        label: const Text('ایجاد کالا یا خدمت'))
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'جست‌وجوی نام کالا یا خدمت...'),
                      onSubmitted: (v) => cubit.load(search: v)),
                  const SizedBox(height: 12),
                  if (state.phase == ItemPhase.loading)
                    const LinearProgressIndicator(),
                  if (state.error != null)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(state.error!,
                            style: const TextStyle(color: Colors.red))),
                  Expanded(
                      child: Card(
                          child: SingleChildScrollView(
                              child: DataTable(columns: const [
                    DataColumn(label: Text('کد')),
                    DataColumn(label: Text('نام')),
                    DataColumn(label: Text('نوع')),
                    DataColumn(label: Text('گروه')),
                    DataColumn(label: Text('واحد')),
                    DataColumn(label: Text('وضعیت'))
                  ], rows: [
                    for (final item in state.snapshot.items)
                      DataRow(
                          onSelectChanged: (_) => cubit.edit(item.code),
                          cells: [
                            DataCell(Text(item.code)),
                            DataCell(Text(item.name)),
                            DataCell(
                                Text(item.kind == 'Goods' ? 'کالا' : 'خدمت')),
                            DataCell(Text(item.group)),
                            DataCell(Text(item.uom)),
                            DataCell(Chip(
                                label: Text(item.enabled ? 'فعال' : 'غیرفعال')))
                          ])
                  ]))))
                ]));
      });
}

class _ItemForm extends StatelessWidget {
  const _ItemForm(
      {required this.draft, required this.options, required this.cubit});
  final ItemDraft draft;
  final ItemOptions options;
  final ItemManagementCubit cubit;
  List<String> withValue(List<String> rows, String value) =>
      {if (value.isNotEmpty) value, ...rows}.toList();
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconButton(
                  onPressed: cubit.cancel,
                  icon: const Icon(Icons.arrow_forward)),
              Expanded(
                  child: Text(
                      draft.itemCode == null
                          ? 'ایجاد کالا یا خدمت'
                          : 'ویرایش ${draft.itemCode}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800))),
              OutlinedButton(
                  onPressed: cubit.cancel, child: const Text('انصراف')),
              const SizedBox(width: 8),
              FilledButton.icon(
                  onPressed: cubit.save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیره'))
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1050),
                        child: Column(children: [
                          _card(
                              'اطلاعات پایه',
                              Icons.inventory_2_outlined,
                              Column(children: [
                                SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                          value: 'Goods',
                                          label: Text('کالا'),
                                          icon:
                                              Icon(Icons.inventory_2_outlined)),
                                      ButtonSegment(
                                          value: 'Service',
                                          label: Text('خدمت'),
                                          icon: Icon(
                                              Icons.design_services_outlined))
                                    ],
                                    selected: {
                                      draft.itemKind
                                    },
                                    onSelectionChanged: (v) => cubit.update(
                                        draft.copyWith(itemKind: v.first))),
                                const SizedBox(height: 12),
                                TextFormField(
                                    initialValue: draft.itemName,
                                    decoration: const InputDecoration(
                                        labelText: 'نام *'),
                                    onChanged: (v) => cubit
                                        .update(draft.copyWith(itemName: v))),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                      child: _select(
                                          'گروه *',
                                          draft.itemGroup,
                                          options.itemGroups,
                                          (v) => cubit.update(
                                              draft.copyWith(itemGroup: v)))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _select(
                                          'واحد سنجش *',
                                          draft.stockUom,
                                          options.uoms,
                                          (v) => cubit.update(
                                              draft.copyWith(stockUom: v))))
                                ]),
                                const SizedBox(height: 10),
                                TextFormField(
                                    initialValue: draft.description,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration:
                                        const InputDecoration(labelText: 'شرح'),
                                    onChanged: (v) => cubit.update(
                                        draft.copyWith(description: v))),
                              ])),
                          const SizedBox(height: 12),
                          _card(
                              'تنظیمات شرکت فعال',
                              Icons.business_outlined,
                              Column(children: [
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('فعال در شرکت جاری'),
                                    value: draft.enabled,
                                    onChanged: (v) => cubit
                                        .update(draft.copyWith(enabled: v))),
                                Row(children: [
                                  Expanded(
                                      child: _select(
                                          'شعبه پیش‌فرض',
                                          draft.defaultBranch,
                                          options.branches,
                                          (v) => cubit.update(draft.copyWith(
                                              defaultBranch: v)))),
                                  const SizedBox(width: 10),
                                  if (draft.itemKind == 'Goods')
                                    Expanded(
                                        child: _select(
                                            'انبار پیش‌فرض',
                                            draft.defaultWarehouse,
                                            options.warehouses,
                                            (v) => cubit.update(draft.copyWith(
                                                defaultWarehouse: v))))
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                      child: _select(
                                          'حساب درآمد',
                                          draft.incomeAccount,
                                          options.incomeAccounts,
                                          (v) => cubit.update(draft.copyWith(
                                              incomeAccount: v)))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _select(
                                          'حساب هزینه',
                                          draft.expenseAccount,
                                          options.expenseAccounts,
                                          (v) => cubit.update(draft.copyWith(
                                              expenseAccount: v))))
                                ]),
                              ])),
                          const SizedBox(height: 12),
                          _card(
                              'وضعیت هویت مشترک',
                              Icons.shield_outlined,
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('غیرفعال در کل هلدینگ'),
                                  subtitle: const Text(
                                      'برای توقف کامل استفاده در همه شرکت‌ها؛ وضعیت هر شرکت در بخش بالا مستقل است.'),
                                  value: draft.disabled,
                                  onChanged: (v) => cubit
                                      .update(draft.copyWith(disabled: v))))
                        ])))))
      ]);
  Widget _card(String title, IconData icon, Widget child) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: AsoudColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800))
            ]),
            const Divider(height: 24),
            child
          ])));
  Widget _select(String label, String value, List<String> rows,
          ValueChanged<String> changed) =>
      DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('انتخاب نشده')),
            for (final row in withValue(rows, value))
              DropdownMenuItem(value: row, child: Text(row))
          ],
          onChanged: (v) => changed(v ?? ''));
}
