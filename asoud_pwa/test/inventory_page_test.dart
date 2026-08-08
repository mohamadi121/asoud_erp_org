import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/items/presentation/inventory_page.dart';
import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operations_snapshot.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the locked-style inventory dashboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: InventoryPage(
              context: const WorkContext(company: 'A', branch: 'HQ'),
              itemGateway: _InventoryGateway(),
              operationsGateway: _OperationsGateway(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('داشبورد انبار'), findsOneWidget);
    expect(find.text('کالا و خدمت فعال'), findsOneWidget);
    expect(find.text('ارزش موجودی'), findsOneWidget);
    expect(find.text('آخرین گردش‌های انبار'), findsOneWidget);
  });

  testWidgets('opens the standard warehouse creation form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: InventoryPage(
              context: const WorkContext(company: 'A', branch: 'HQ'),
              itemGateway: _InventoryGateway(),
              operationsGateway: _OperationsGateway(),
              initialSection: InventorySection.warehouses,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('انبار جدید'));
    await tester.pumpAndSettle();

    expect(find.text('ایجاد انبار'), findsOneWidget);
    expect(find.text('نام انبار *'), findsOneWidget);
    expect(find.text('نوع انبار'), findsOneWidget);
    expect(find.text('شعبه'), findsOneWidget);
  });
}

class _InventoryGateway implements ItemGateway {
  @override
  Future<InventoryWorkspace> loadInventory(WorkContext context) async =>
      const InventoryWorkspace(
        canManage: true,
        dashboard: InventoryDashboard(
          itemCount: 12,
          goodsCount: 10,
          serviceCount: 2,
          warehouseCount: 3,
          actualQty: 150,
          stockValue: 25000000,
        ),
        warehouses: [
          InventoryRow({
            'name': 'Stores - A',
            'warehouse_name': 'انبار مرکزی',
            'branch': 'HQ',
          }),
        ],
        warehouseTypes: [
          InventoryRow({'name': 'Raw Material', 'description': 'مواد اولیه'}),
        ],
        branches: {'HQ': 'دفتر مرکزی'},
      );

  @override
  Future<void> saveInventorySetting(
    WorkContext context,
    InventorySettingDraft draft,
  ) async {}

  @override
  Future<ItemSnapshot> load(WorkContext context, {String search = ''}) async =>
      const ItemSnapshot();

  @override
  Future<ItemDraft> detail(WorkContext context, String itemCode) =>
      throw UnimplementedError();

  @override
  Future<void> save(WorkContext context, ItemDraft draft) async {}
}

class _OperationsGateway implements OperationsGateway {
  @override
  Future<OperationsSnapshot> load(WorkContext context) =>
      throw UnimplementedError();

  @override
  Future<OperationalWorkbench> loadWorkbench(WorkContext context) =>
      throw UnimplementedError();

  @override
  Future<List<String>> linkOptions({
    required String documentType,
    required String fieldname,
    String search = '',
    bool child = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<String>> eligibleFloatingDetails({
    required WorkContext context,
    required String account,
    String search = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<String> createDraft({
    required WorkContext context,
    required String documentType,
    required Map<String, dynamic> payload,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> transition({
    required String documentType,
    required String name,
    required String action,
    String reason = '',
  }) =>
      throw UnimplementedError();
}
