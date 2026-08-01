import 'dart:convert';
import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeItemGateway implements ItemGateway {
  const FrappeItemGateway(this.client);
  final AsoudApiClient client;
  Map<String, dynamic> _message(Map<String, dynamic> response) =>
      response['message'] as Map<String, dynamic>;
  @override
  Future<ItemSnapshot> load(WorkContext context, {String search = ''}) async =>
      ItemSnapshot.fromJson(_message(await client
          .getQuery('/api/method/asoud_core.api.item_management_snapshot', {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
        if (search.isNotEmpty) 'search': search
      })));
  @override
  Future<ItemDraft> detail(WorkContext context, String itemCode) async {
    final data = _message(await client.getQuery(
        '/api/method/asoud_core.api.item_management_detail',
        {'company': context.company, 'item_code': itemCode}));
    return ItemDraft.fromJson(data['item'] as Map<String, dynamic>,
        data['profile'] as Map<String, dynamic>);
  }

  @override
  Future<void> save(WorkContext context, ItemDraft draft) async {
    await client.postForm('/api/method/asoud_core.api.save_item_master', {
      'company': context.company,
      if (context.branch != null) 'branch': context.branch!,
      'payload': jsonEncode(draft.toJson()),
      'idempotency_key': 'item-${DateTime.now().microsecondsSinceEpoch}'
    });
  }
}
