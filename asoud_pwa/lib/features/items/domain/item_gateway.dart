import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class ItemGateway {
  Future<ItemSnapshot> load(WorkContext context, {String search = ''});
  Future<ItemDraft> detail(WorkContext context, String itemCode);
  Future<void> save(WorkContext context, ItemDraft draft);

  Future<InventoryWorkspace> loadInventory(WorkContext context);

  Future<void> saveInventorySetting(
    WorkContext context,
    InventorySettingDraft draft,
  );
}
