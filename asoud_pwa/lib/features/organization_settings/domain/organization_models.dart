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

class FinancialSettingsSnapshot extends Equatable {
  const FinancialSettingsSnapshot({
    required this.company,
    required this.companyName,
    required this.baseCurrency,
    required this.coaTemplate,
    required this.amountInputUnit,
    required this.calendarDisplay,
    required this.timezone,
    required this.setupStatus,
    this.templates = const [],
    this.fiscalYears = const [],
    this.periodLocks = const [],
  });

  factory FinancialSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final settings =
        json['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    List<Map<String, dynamic>> rows(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.unmodifiable)
            .toList(growable: false);
    return FinancialSettingsSnapshot(
      company: settings['company']?.toString() ?? '',
      companyName: settings['company_name']?.toString() ?? '',
      baseCurrency: settings['base_currency']?.toString() ?? 'IRR',
      coaTemplate: settings['coa_template']?.toString() ?? '',
      amountInputUnit: settings['amount_input_unit']?.toString() ?? 'IRR',
      calendarDisplay: settings['calendar_display']?.toString() ?? 'Jalali',
      timezone: settings['timezone']?.toString() ?? 'Asia/Tehran',
      setupStatus: settings['setup_status']?.toString() ?? 'Pending',
      templates: rows('coa_templates'),
      fiscalYears: rows('fiscal_years'),
      periodLocks: rows('period_locks'),
    );
  }

  final String company;
  final String companyName;
  final String baseCurrency;
  final String coaTemplate;
  final String amountInputUnit;
  final String calendarDisplay;
  final String timezone;
  final String setupStatus;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> fiscalYears;
  final List<Map<String, dynamic>> periodLocks;

  FinancialSettingsDraft toDraft() => FinancialSettingsDraft(
        coaTemplate: coaTemplate,
        amountInputUnit: amountInputUnit,
        calendarDisplay: calendarDisplay,
      );

  @override
  List<Object?> get props => [
        company,
        companyName,
        baseCurrency,
        coaTemplate,
        amountInputUnit,
        calendarDisplay,
        timezone,
        setupStatus,
        templates,
        fiscalYears,
        periodLocks,
      ];
}

class FinancialSettingsDraft extends Equatable {
  const FinancialSettingsDraft({
    this.coaTemplate = '',
    this.amountInputUnit = 'IRR',
    this.calendarDisplay = 'Jalali',
  });

  final String coaTemplate;
  final String amountInputUnit;
  final String calendarDisplay;

  FinancialSettingsDraft copyWith({
    String? coaTemplate,
    String? amountInputUnit,
    String? calendarDisplay,
  }) =>
      FinancialSettingsDraft(
        coaTemplate: coaTemplate ?? this.coaTemplate,
        amountInputUnit: amountInputUnit ?? this.amountInputUnit,
        calendarDisplay: calendarDisplay ?? this.calendarDisplay,
      );

  Map<String, dynamic> toJson() => {
        'coa_template': coaTemplate,
        'amount_input_unit': amountInputUnit,
        'calendar_display': calendarDisplay,
      };

  @override
  List<Object?> get props => [
        coaTemplate,
        amountInputUnit,
        calendarDisplay,
      ];
}
