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

class ChartAccount extends Equatable {
  const ChartAccount({
    required this.name,
    required this.accountName,
    required this.accountNumber,
    required this.parentAccount,
    required this.rootType,
    required this.reportType,
    required this.accountType,
    required this.accountCurrency,
    required this.isGroup,
    required this.disabled,
  });

  factory ChartAccount.fromJson(Map<String, dynamic> json) => ChartAccount(
        name: json['name']?.toString() ?? '',
        accountName: json['account_name']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        parentAccount: json['parent_account']?.toString() ?? '',
        rootType: json['root_type']?.toString() ?? '',
        reportType: json['report_type']?.toString() ?? '',
        accountType: json['account_type']?.toString() ?? '',
        accountCurrency: json['account_currency']?.toString() ?? 'IRR',
        isGroup: json['is_group'] == 1 || json['is_group'] == true,
        disabled: json['disabled'] == 1 || json['disabled'] == true,
      );

  final String name;
  final String accountName;
  final String accountNumber;
  final String parentAccount;
  final String rootType;
  final String reportType;
  final String accountType;
  final String accountCurrency;
  final bool isGroup;
  final bool disabled;

  @override
  List<Object?> get props => [
        name,
        accountName,
        accountNumber,
        parentAccount,
        rootType,
        reportType,
        accountType,
        accountCurrency,
        isGroup,
        disabled,
      ];
}

class AccountDetailRuleDraft extends Equatable {
  const AccountDetailRuleDraft({
    required this.detailType,
    this.required = false,
    this.enabled = true,
    this.defaultFloatingDetail = '',
    this.validFrom = '',
    this.validTo = '',
  });

  factory AccountDetailRuleDraft.fromJson(Map<String, dynamic> json) =>
      AccountDetailRuleDraft(
        detailType: json['detail_type']?.toString() ?? '',
        required: json['required'] == 1 || json['required'] == true,
        enabled: json['enabled'] == 1 || json['enabled'] == true,
        defaultFloatingDetail:
            json['default_floating_detail']?.toString() ?? '',
        validFrom: json['valid_from']?.toString() ?? '',
        validTo: json['valid_to']?.toString() ?? '',
      );

  final String detailType;
  final bool required;
  final bool enabled;
  final String defaultFloatingDetail;
  final String validFrom;
  final String validTo;

  AccountDetailRuleDraft copyWith({
    String? detailType,
    bool? required,
    bool? enabled,
    String? defaultFloatingDetail,
    String? validFrom,
    String? validTo,
  }) =>
      AccountDetailRuleDraft(
        detailType: detailType ?? this.detailType,
        required: required ?? this.required,
        enabled: enabled ?? this.enabled,
        defaultFloatingDetail:
            defaultFloatingDetail ?? this.defaultFloatingDetail,
        validFrom: validFrom ?? this.validFrom,
        validTo: validTo ?? this.validTo,
      );

  Map<String, dynamic> toJson() => {
        'detail_type': detailType,
        'required': required,
        'enabled': enabled,
        'default_floating_detail':
            defaultFloatingDetail.trim().isEmpty ? null : defaultFloatingDetail,
        'valid_from': validFrom.trim().isEmpty ? null : validFrom,
        'valid_to': validTo.trim().isEmpty ? null : validTo,
      };

  @override
  List<Object?> get props => [
        detailType,
        required,
        enabled,
        defaultFloatingDetail,
        validFrom,
        validTo,
      ];
}

class AccountRulesSnapshot extends Equatable {
  const AccountRulesSnapshot({
    required this.company,
    this.detailTypes = const [],
    this.floatingDetails = const [],
    this.accounts = const [],
    this.rules = const {},
  });

  factory AccountRulesSnapshot.fromJson(Map<String, dynamic> json) {
    final accounts = (json['accounts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChartAccount.fromJson)
        .toList(growable: false);
    final grouped = <String, List<AccountDetailRuleDraft>>{};
    for (final row in (json['rules'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final account = row['account']?.toString() ?? '';
      grouped
          .putIfAbsent(account, () => [])
          .add(AccountDetailRuleDraft.fromJson(row));
    }
    return AccountRulesSnapshot(
      company: json['company']?.toString() ?? '',
      detailTypes: (json['detail_types'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      floatingDetails: (json['floating_details'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.unmodifiable)
          .toList(growable: false),
      accounts: accounts,
      rules: Map<String, List<AccountDetailRuleDraft>>.unmodifiable({
        for (final entry in grouped.entries)
          entry.key: List<AccountDetailRuleDraft>.unmodifiable(entry.value),
      }),
    );
  }

  final String company;
  final List<String> detailTypes;
  final List<Map<String, dynamic>> floatingDetails;
  final List<ChartAccount> accounts;
  final Map<String, List<AccountDetailRuleDraft>> rules;

  @override
  List<Object?> get props =>
      [company, detailTypes, floatingDetails, accounts, rules];
}

class ChartAccountDraft extends Equatable {
  const ChartAccountDraft({
    this.name = '',
    this.accountName = '',
    this.accountNumber = '',
    this.parentAccount = '',
    this.accountType = '',
    this.accountCurrency = 'IRR',
    this.isGroup = false,
    this.disabled = false,
    this.rules = const [],
  });

  factory ChartAccountDraft.fromAccount(
    ChartAccount account,
    List<AccountDetailRuleDraft> rules,
  ) =>
      ChartAccountDraft(
        name: account.name,
        accountName: account.accountName,
        accountNumber: account.accountNumber,
        parentAccount: account.parentAccount,
        accountType: account.accountType,
        accountCurrency: account.accountCurrency,
        isGroup: account.isGroup,
        disabled: account.disabled,
        rules: rules,
      );

  final String name;
  final String accountName;
  final String accountNumber;
  final String parentAccount;
  final String accountType;
  final String accountCurrency;
  final bool isGroup;
  final bool disabled;
  final List<AccountDetailRuleDraft> rules;

  ChartAccountDraft copyWith({
    String? name,
    String? accountName,
    String? accountNumber,
    String? parentAccount,
    String? accountType,
    String? accountCurrency,
    bool? isGroup,
    bool? disabled,
    List<AccountDetailRuleDraft>? rules,
  }) =>
      ChartAccountDraft(
        name: name ?? this.name,
        accountName: accountName ?? this.accountName,
        accountNumber: accountNumber ?? this.accountNumber,
        parentAccount: parentAccount ?? this.parentAccount,
        accountType: accountType ?? this.accountType,
        accountCurrency: accountCurrency ?? this.accountCurrency,
        isGroup: isGroup ?? this.isGroup,
        disabled: disabled ?? this.disabled,
        rules: rules ?? this.rules,
      );

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        'account_name': accountName,
        'account_number': accountNumber,
        'parent_account': parentAccount,
        'account_type': accountType,
        'account_currency': accountCurrency,
        'is_group': isGroup,
        'disabled': disabled,
        'rules': rules.map((rule) => rule.toJson()).toList(growable: false),
      };

  @override
  List<Object?> get props => [
        name,
        accountName,
        accountNumber,
        parentAccount,
        accountType,
        accountCurrency,
        isGroup,
        disabled,
        rules,
      ];
}
