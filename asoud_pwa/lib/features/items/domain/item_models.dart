import 'package:equatable/equatable.dart';

class ItemOptions extends Equatable {
  const ItemOptions({
    this.itemGroups = const [],
    this.uoms = const [],
    this.branches = const [],
    this.warehouses = const [],
    this.incomeAccounts = const [],
    this.expenseAccounts = const [],
  });
  factory ItemOptions.fromJson(Map<String, dynamic> json) {
    List<String> rows(String key) =>
        (json[key] as List<dynamic>? ?? const []).map((e) => '$e').toList();
    return ItemOptions(
        itemGroups: rows('item_groups'),
        uoms: rows('uoms'),
        branches: rows('branches'),
        warehouses: rows('warehouses'),
        incomeAccounts: rows('income_accounts'),
        expenseAccounts: rows('expense_accounts'));
  }
  final List<String> itemGroups,
      uoms,
      branches,
      warehouses,
      incomeAccounts,
      expenseAccounts;
  @override
  List<Object?> get props =>
      [itemGroups, uoms, branches, warehouses, incomeAccounts, expenseAccounts];
}

class ItemDraft extends Equatable {
  const ItemDraft(
      {this.itemCode,
      this.itemName = '',
      this.itemKind = 'Goods',
      this.itemGroup = '',
      this.stockUom = '',
      this.description = '',
      this.disabled = false,
      this.enabled = true,
      this.defaultBranch = '',
      this.defaultWarehouse = '',
      this.incomeAccount = '',
      this.expenseAccount = ''});
  factory ItemDraft.fromJson(Map<String, dynamic> json,
          [Map<String, dynamic> profile = const {}]) =>
      ItemDraft(
          itemCode: json['name']?.toString(),
          itemName: json['item_name']?.toString() ?? '',
          itemKind: json['asoud_item_kind']?.toString() ?? 'Goods',
          itemGroup: json['item_group']?.toString() ?? '',
          stockUom: json['stock_uom']?.toString() ?? '',
          description: json['description']?.toString() ?? '',
          disabled: json['disabled'] == 1 || json['disabled'] == true,
          enabled: profile['enabled'] != 0 && profile['enabled'] != false,
          defaultBranch: profile['default_branch']?.toString() ?? '',
          defaultWarehouse: profile['default_warehouse']?.toString() ?? '',
          incomeAccount: profile['income_account']?.toString() ?? '',
          expenseAccount: profile['expense_account']?.toString() ?? '');
  final String? itemCode;
  final String itemName,
      itemKind,
      itemGroup,
      stockUom,
      description,
      defaultBranch,
      defaultWarehouse,
      incomeAccount,
      expenseAccount;
  final bool disabled, enabled;
  ItemDraft copyWith(
          {String? itemName,
          String? itemKind,
          String? itemGroup,
          String? stockUom,
          String? description,
          bool? disabled,
          bool? enabled,
          String? defaultBranch,
          String? defaultWarehouse,
          String? incomeAccount,
          String? expenseAccount}) =>
      ItemDraft(
          itemCode: itemCode,
          itemName: itemName ?? this.itemName,
          itemKind: itemKind ?? this.itemKind,
          itemGroup: itemGroup ?? this.itemGroup,
          stockUom: stockUom ?? this.stockUom,
          description: description ?? this.description,
          disabled: disabled ?? this.disabled,
          enabled: enabled ?? this.enabled,
          defaultBranch: defaultBranch ?? this.defaultBranch,
          defaultWarehouse: defaultWarehouse ?? this.defaultWarehouse,
          incomeAccount: incomeAccount ?? this.incomeAccount,
          expenseAccount: expenseAccount ?? this.expenseAccount);
  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'item_name': itemName,
        'item_kind': itemKind,
        'item_group': itemGroup,
        'stock_uom': stockUom,
        'description': description,
        'disabled': disabled,
        'enabled': enabled,
        'default_branch': defaultBranch,
        'default_warehouse': defaultWarehouse,
        'income_account': incomeAccount,
        'expense_account': expenseAccount
      };
  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        itemKind,
        itemGroup,
        stockUom,
        description,
        disabled,
        enabled,
        defaultBranch,
        defaultWarehouse,
        incomeAccount,
        expenseAccount
      ];
}

class ItemSummary extends Equatable {
  const ItemSummary(
      {required this.code,
      required this.name,
      required this.kind,
      required this.group,
      required this.uom,
      required this.enabled});
  factory ItemSummary.fromJson(Map<String, dynamic> json) {
    final p = json['profile'] as Map<String, dynamic>? ?? const {};
    return ItemSummary(
        code: json['name']?.toString() ?? '',
        name: json['item_name']?.toString() ?? '',
        kind: json['asoud_item_kind']?.toString() ?? 'Goods',
        group: json['item_group']?.toString() ?? '',
        uom: json['stock_uom']?.toString() ?? '',
        enabled: p['enabled'] != 0 && p['enabled'] != false);
  }
  final String code, name, kind, group, uom;
  final bool enabled;
  @override
  List<Object?> get props => [code, name, kind, group, uom, enabled];
}

class ItemSnapshot extends Equatable {
  const ItemSnapshot(
      {this.items = const [], this.options = const ItemOptions()});
  factory ItemSnapshot.fromJson(Map<String, dynamic> json) => ItemSnapshot(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ItemSummary.fromJson)
          .toList(),
      options: ItemOptions.fromJson(
          json['options'] as Map<String, dynamic>? ?? const {}));
  final List<ItemSummary> items;
  final ItemOptions options;
  @override
  List<Object?> get props => [items, options];
}
