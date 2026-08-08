import 'package:equatable/equatable.dart';

class InventoryDashboard extends Equatable {
  const InventoryDashboard({
    this.itemCount = 0,
    this.goodsCount = 0,
    this.serviceCount = 0,
    this.warehouseCount = 0,
    this.actualQty = 0,
    this.stockValue = 0,
    this.stockedItems = 0,
    this.negativeBins = 0,
    this.recentMovements = const [],
  });

  factory InventoryDashboard.fromJson(Map<String, dynamic> json) =>
      InventoryDashboard(
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        goodsCount: (json['goods_count'] as num?)?.toInt() ?? 0,
        serviceCount: (json['service_count'] as num?)?.toInt() ?? 0,
        warehouseCount: (json['warehouse_count'] as num?)?.toInt() ?? 0,
        actualQty: (json['actual_qty'] as num?)?.toDouble() ?? 0,
        stockValue: (json['stock_value'] as num?)?.toDouble() ?? 0,
        stockedItems: (json['stocked_items'] as num?)?.toInt() ?? 0,
        negativeBins: (json['negative_bins'] as num?)?.toInt() ?? 0,
        recentMovements:
            (json['recent_movements'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(StockMovementSummary.fromJson)
                .toList(growable: false),
      );

  final int itemCount;
  final int goodsCount;
  final int serviceCount;
  final int warehouseCount;
  final double actualQty;
  final double stockValue;
  final int stockedItems;
  final int negativeBins;
  final List<StockMovementSummary> recentMovements;

  @override
  List<Object?> get props => [
        itemCount,
        goodsCount,
        serviceCount,
        warehouseCount,
        actualQty,
        stockValue,
        stockedItems,
        negativeBins,
        recentMovements,
      ];
}

class StockMovementSummary extends Equatable {
  const StockMovementSummary({
    required this.name,
    required this.type,
    required this.postingDate,
    required this.docstatus,
  });

  factory StockMovementSummary.fromJson(Map<String, dynamic> json) =>
      StockMovementSummary(
        name: json['name']?.toString() ?? '',
        type: json['stock_entry_type']?.toString() ?? '',
        postingDate: json['posting_date']?.toString() ?? '',
        docstatus: (json['docstatus'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final String type;
  final String postingDate;
  final int docstatus;

  @override
  List<Object?> get props => [name, type, postingDate, docstatus];
}

class InventoryRow extends Equatable {
  const InventoryRow(this.values);

  factory InventoryRow.fromJson(Map<String, dynamic> json) =>
      InventoryRow(Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> values;
  String text(String key) => values[key]?.toString() ?? '';
  bool flag(String key) => values[key] == true || values[key] == 1;
  double number(String key) => (values[key] as num?)?.toDouble() ?? 0;

  @override
  List<Object?> get props => [values];
}

class InventoryWorkspace extends Equatable {
  const InventoryWorkspace({
    this.canManage = false,
    this.dashboard = const InventoryDashboard(),
    this.warehouses = const [],
    this.warehouseTypes = const [],
    this.itemGroups = const [],
    this.uoms = const [],
    this.uomCategories = const [],
    this.uomConversions = const [],
    this.branches = const {},
    this.accounts = const [],
  });

  factory InventoryWorkspace.fromJson(Map<String, dynamic> json) {
    List<InventoryRow> rows(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(InventoryRow.fromJson)
            .toList(growable: false);
    return InventoryWorkspace(
      canManage: json['can_manage'] == true || json['can_manage'] == 1,
      dashboard: InventoryDashboard.fromJson(
        json['dashboard'] as Map<String, dynamic>? ?? const {},
      ),
      warehouses: rows('warehouses'),
      warehouseTypes: rows('warehouse_types'),
      itemGroups: rows('item_groups'),
      uoms: rows('uoms'),
      uomCategories: rows('uom_categories'),
      uomConversions: rows('uom_conversions'),
      branches: {
        for (final row in rows('branches'))
          row.text('name'): row.text('branch_name'),
      },
      accounts: (json['accounts'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }

  final bool canManage;
  final InventoryDashboard dashboard;
  final List<InventoryRow> warehouses;
  final List<InventoryRow> warehouseTypes;
  final List<InventoryRow> itemGroups;
  final List<InventoryRow> uoms;
  final List<InventoryRow> uomCategories;
  final List<InventoryRow> uomConversions;
  final Map<String, String> branches;
  final List<String> accounts;

  @override
  List<Object?> get props => [
        canManage,
        dashboard,
        warehouses,
        warehouseTypes,
        itemGroups,
        uoms,
        uomCategories,
        uomConversions,
        branches,
        accounts,
      ];
}

class InventorySettingDraft extends Equatable {
  const InventorySettingDraft({
    required this.settingType,
    this.name = '',
    this.label = '',
    this.description = '',
    this.parent = '',
    this.warehouseType = '',
    this.branch = '',
    this.account = '',
    this.category = '',
    this.fromUom = '',
    this.toUom = '',
    this.value = 0,
    this.isGroup = false,
    this.disabled = false,
    this.enabled = true,
    this.wholeNumber = false,
  });

  final String settingType;
  final String name;
  final String label;
  final String description;
  final String parent;
  final String warehouseType;
  final String branch;
  final String account;
  final String category;
  final String fromUom;
  final String toUom;
  final double value;
  final bool isGroup;
  final bool disabled;
  final bool enabled;
  final bool wholeNumber;

  Map<String, dynamic> toJson() => switch (settingType) {
        'Warehouse' => {
            if (name.isNotEmpty) 'name': name,
            'warehouse_name': label,
            'parent_warehouse': parent,
            'warehouse_type': warehouseType,
            'branch': branch,
            'account': account,
            'is_group': isGroup,
            'disabled': disabled,
          },
        'Warehouse Type' => {
            if (name.isNotEmpty) 'name': name,
            'warehouse_type': label,
            'description': description,
          },
        'Item Group' => {
            if (name.isNotEmpty) 'name': name,
            'item_group_name': label,
            'parent_item_group': parent,
            'is_group': isGroup,
          },
        'UOM' => {
            if (name.isNotEmpty) 'name': name,
            'uom_name': label,
            'enabled': enabled,
            'must_be_whole_number': wholeNumber,
          },
        'UOM Category' => {
            if (name.isNotEmpty) 'name': name,
            'category_name': label,
          },
        _ => {
            if (name.isNotEmpty) 'name': name,
            'category': category,
            'from_uom': fromUom,
            'to_uom': toUom,
            'value': value,
          },
      };

  @override
  List<Object?> get props => [
        settingType,
        name,
        label,
        description,
        parent,
        warehouseType,
        branch,
        account,
        category,
        fromUom,
        toUom,
        value,
        isGroup,
        disabled,
        enabled,
        wholeNumber,
      ];
}
