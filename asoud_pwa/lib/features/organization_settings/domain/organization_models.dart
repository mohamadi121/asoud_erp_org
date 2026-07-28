import 'package:equatable/equatable.dart';

enum OrganizationUnitKind { holding, company, branch }

class OrganizationUnit extends Equatable {
  const OrganizationUnit({
    required this.name,
    required this.title,
    required this.kind,
    this.code,
    this.parent,
    this.enabled = true,
    this.values = const {},
  });

  factory OrganizationUnit.fromJson(
    Map<String, dynamic> json,
    OrganizationUnitKind kind,
  ) {
    final titleField = switch (kind) {
      OrganizationUnitKind.holding => 'holding_name',
      OrganizationUnitKind.company => 'company_name',
      OrganizationUnitKind.branch => 'branch_name',
    };
    final codeField = switch (kind) {
      OrganizationUnitKind.holding => 'holding_code',
      OrganizationUnitKind.company => 'abbr',
      OrganizationUnitKind.branch => 'branch_code',
    };
    return OrganizationUnit(
      name: json['name']?.toString() ?? '',
      title: json[titleField]?.toString() ?? json['name']?.toString() ?? '',
      code: json[codeField]?.toString(),
      parent: (json['holding'] ?? json['asoud_holding'] ?? json['company'])
          ?.toString(),
      kind: kind,
      enabled: json['enabled'] != 0,
      values: Map.unmodifiable(json),
    );
  }

  final String name;
  final String title;
  final String? code;
  final String? parent;
  final OrganizationUnitKind kind;
  final bool enabled;
  final Map<String, dynamic> values;

  @override
  List<Object?> get props => [name, title, code, parent, kind, enabled, values];
}

class OrganizationSnapshot extends Equatable {
  const OrganizationSnapshot({
    this.holdings = const [],
    this.companies = const [],
    this.branches = const [],
  });

  factory OrganizationSnapshot.fromJson(Map<String, dynamic> json) {
    List<OrganizationUnit> rows(String key, OrganizationUnitKind kind) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((row) => OrganizationUnit.fromJson(row, kind))
            .toList(growable: false);
    return OrganizationSnapshot(
      holdings: rows('holdings', OrganizationUnitKind.holding),
      companies: rows('companies', OrganizationUnitKind.company),
      branches: rows('branches', OrganizationUnitKind.branch),
    );
  }

  final List<OrganizationUnit> holdings;
  final List<OrganizationUnit> companies;
  final List<OrganizationUnit> branches;

  @override
  List<Object?> get props => [holdings, companies, branches];
}

class OrganizationDraft extends Equatable {
  const OrganizationDraft({
    required this.kind,
    this.step = 0,
    this.values = const {},
  });

  final OrganizationUnitKind kind;
  final int step;
  final Map<String, String> values;

  OrganizationDraft copyWith({
    OrganizationUnitKind? kind,
    int? step,
    Map<String, String>? values,
  }) =>
      OrganizationDraft(
        kind: kind ?? this.kind,
        step: step ?? this.step,
        values: values ?? this.values,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        ...values,
      };

  @override
  List<Object?> get props => [kind, step, values];
}
