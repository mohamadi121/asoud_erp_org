import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:asoud_pwa/features/items/presentation/bloc/item_management_cubit.dart';
import 'package:asoud_pwa/features/items/presentation/bloc/inventory_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = WorkContext(company: 'ASOUD', branch: 'HQ');

  test('creates and saves a company-scoped goods master', () async {
    final gateway = _FakeItemGateway();
    final cubit = ItemManagementCubit(gateway, context);
    await cubit.load();
    cubit.create();
    cubit.update(cubit.state.draft!.copyWith(
      itemName: 'کالای نمونه',
      itemGroup: 'Products',
      stockUom: 'Nos',
      defaultBranch: 'HQ',
      defaultWarehouse: 'Stores - A',
    ));
    await cubit.save();
    expect(gateway.saved.single.itemKind, 'Goods');
    expect(gateway.saved.single.defaultBranch, 'HQ');
    expect(cubit.state.draft, isNull);
    await cubit.close();
  });

  test('service draft serializes without changing company policy', () {
    const draft = ItemDraft(
      itemName: 'خدمت نصب',
      itemKind: 'Service',
      itemGroup: 'Services',
      stockUom: 'Hour',
      enabled: false,
      incomeAccount: 'Service Income - A',
    );
    expect(draft.toJson()['item_kind'], 'Service');
    expect(draft.toJson()['enabled'], isFalse);
  });

  test('loads dashboard and saves a warehouse setting', () async {
    final gateway = _FakeItemGateway();
    final cubit = InventoryCubit(gateway, context);

    await cubit.load();
    expect(cubit.state.workspace.dashboard.warehouseCount, 2);

    final saved = await cubit.save(const InventorySettingDraft(
      settingType: 'Warehouse',
      label: 'مواد اولیه',
      branch: 'HQ',
    ));

    expect(saved, isTrue);
    expect(gateway.savedSettings.single.label, 'مواد اولیه');
    await cubit.close();
  });
}

class _FakeItemGateway implements ItemGateway {
  final saved = <ItemDraft>[];
  final savedSettings = <InventorySettingDraft>[];
  @override
  Future<ItemSnapshot> load(WorkContext context, {String search = ''}) async =>
      const ItemSnapshot(
        options: ItemOptions(
          itemGroups: ['Products'],
          uoms: ['Nos'],
          branches: ['HQ'],
        ),
      );
  @override
  Future<ItemDraft> detail(WorkContext context, String itemCode) async =>
      ItemDraft(itemCode: itemCode, itemName: 'Sample');
  @override
  Future<void> save(WorkContext context, ItemDraft draft) async =>
      saved.add(draft);

  @override
  Future<InventoryWorkspace> loadInventory(WorkContext context) async =>
      const InventoryWorkspace(
        canManage: true,
        dashboard: InventoryDashboard(warehouseCount: 2),
      );

  @override
  Future<void> saveInventorySetting(
    WorkContext context,
    InventorySettingDraft draft,
  ) async =>
      savedSettings.add(draft);
}
