import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/items/data/frappe_item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads the company and branch scoped inventory workspace', () async {
    late http.Request captured;
    final gateway = FrappeItemGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {
                'can_manage': true,
                'dashboard': {'warehouse_count': 3, 'item_count': 10},
                'warehouses': [],
                'warehouse_types': [],
                'item_groups': [],
                'uoms': [],
                'uom_categories': [],
                'uom_conversions': [],
                'branches': [],
                'accounts': [],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final result = await gateway.loadInventory(
      const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    expect(captured.url.path,
        '/api/method/asoud_core.api.inventory_management_workspace');
    expect(captured.url.queryParameters['company'], 'A');
    expect(captured.url.queryParameters['branch'], 'A-HQ');
    expect(result.dashboard.warehouseCount, 3);
  });

  test('posts an idempotent standard warehouse setting', () async {
    late http.Request captured;
    final gateway = FrappeItemGateway(
      AsoudApiClient(
        baseUrl: 'https://erp.example.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'message': {'name': 'مواد اولیه - A', 'setting_type': 'Warehouse'}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    await gateway.saveInventorySetting(
      const WorkContext(company: 'A', branch: 'A-HQ'),
      const InventorySettingDraft(
        settingType: 'Warehouse',
        label: 'مواد اولیه',
        branch: 'A-HQ',
      ),
    );

    expect(
        captured.url.path, '/api/method/asoud_core.api.save_inventory_setting');
    expect(captured.bodyFields['setting_type'], 'Warehouse');
    expect(captured.bodyFields['idempotency_key'], isNotEmpty);
    final payload = jsonDecode(captured.bodyFields['payload']!);
    expect(payload['warehouse_name'], 'مواد اولیه');
    expect(payload['branch'], 'A-HQ');
  });
}
