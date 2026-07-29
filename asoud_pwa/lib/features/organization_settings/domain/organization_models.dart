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
    this.fiscalPeriods = const [],
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
      fiscalPeriods: rows('fiscal_periods'),
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
  final List<Map<String, dynamic>> fiscalPeriods;
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
        fiscalPeriods,
        periodLocks,
      ];
}

class FiscalYearDraft extends Equatable {
  const FiscalYearDraft({
    this.name = '',
    this.yearName = '',
    this.fromDate = '',
    this.toDate = '',
    this.disabled = false,
  });

  factory FiscalYearDraft.fromJson(Map<String, dynamic> json) =>
      FiscalYearDraft(
        name: json['name']?.toString() ?? '',
        yearName: json['name']?.toString() ?? json['year']?.toString() ?? '',
        fromDate: json['year_start_date']?.toString() ?? '',
        toDate: json['year_end_date']?.toString() ?? '',
        disabled: json['disabled'] == 1 || json['disabled'] == true,
      );

  final String name;
  final String yearName;
  final String fromDate;
  final String toDate;
  final bool disabled;

  FiscalYearDraft copyWith({
    String? yearName,
    String? fromDate,
    String? toDate,
    bool? disabled,
  }) =>
      FiscalYearDraft(
        name: name,
        yearName: yearName ?? this.yearName,
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
        disabled: disabled ?? this.disabled,
      );

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        'year_name': yearName,
        'from_date': fromDate,
        'to_date': toDate,
        'disabled': disabled,
      };

  @override
  List<Object?> get props => [name, yearName, fromDate, toDate, disabled];
}

class FiscalPeriodDraft extends Equatable {
  const FiscalPeriodDraft({
    this.name = '',
    this.fiscalYear = '',
    this.periodName = '',
    this.periodType = 'Standard',
    this.fromDate = '',
    this.toDate = '',
    this.enabled = true,
  });

  factory FiscalPeriodDraft.fromJson(Map<String, dynamic> json) =>
      FiscalPeriodDraft(
        name: json['name']?.toString() ?? '',
        fiscalYear: json['fiscal_year']?.toString() ?? '',
        periodName: json['period_name']?.toString() ?? '',
        periodType: json['period_type']?.toString() ?? 'Standard',
        fromDate: json['from_date']?.toString() ?? '',
        toDate: json['to_date']?.toString() ?? '',
        enabled: json['enabled'] == 1 || json['enabled'] == true,
      );

  final String name;
  final String fiscalYear;
  final String periodName;
  final String periodType;
  final String fromDate;
  final String toDate;
  final bool enabled;

  FiscalPeriodDraft copyWith({
    String? fiscalYear,
    String? periodName,
    String? periodType,
    String? fromDate,
    String? toDate,
    bool? enabled,
  }) =>
      FiscalPeriodDraft(
        name: name,
        fiscalYear: fiscalYear ?? this.fiscalYear,
        periodName: periodName ?? this.periodName,
        periodType: periodType ?? this.periodType,
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        'fiscal_year': fiscalYear,
        'period_name': periodName,
        'period_type': periodType,
        'from_date': fromDate,
        'to_date': toDate,
        'enabled': enabled,
      };

  @override
  List<Object?> get props =>
      [name, fiscalYear, periodName, periodType, fromDate, toDate, enabled];
}

class PeriodLockDraft extends Equatable {
  const PeriodLockDraft({
    this.fiscalYear = '',
    this.fiscalPeriod = '',
    this.fromDate = '',
    this.toDate = '',
    this.reason = '',
  });

  final String fiscalYear;
  final String fiscalPeriod;
  final String fromDate;
  final String toDate;
  final String reason;

  PeriodLockDraft copyWith({
    String? fiscalYear,
    String? fiscalPeriod,
    String? fromDate,
    String? toDate,
    String? reason,
  }) =>
      PeriodLockDraft(
        fiscalYear: fiscalYear ?? this.fiscalYear,
        fiscalPeriod: fiscalPeriod ?? this.fiscalPeriod,
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
        reason: reason ?? this.reason,
      );

  Map<String, dynamic> toJson() => {
        'fiscal_year': fiscalYear,
        'fiscal_period': fiscalPeriod.isEmpty ? null : fiscalPeriod,
        'from_date': fromDate,
        'to_date': toDate,
        'reason': reason,
      };

  @override
  List<Object?> get props =>
      [fiscalYear, fiscalPeriod, fromDate, toDate, reason];
}

class PeriodUnlockDraft extends Equatable {
  const PeriodUnlockDraft({required this.lockName, this.reason = ''});

  final String lockName;
  final String reason;

  PeriodUnlockDraft copyWith({String? reason}) =>
      PeriodUnlockDraft(lockName: lockName, reason: reason ?? this.reason);

  @override
  List<Object?> get props => [lockName, reason];
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
    required this.accountLevel,
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
        accountLevel: json['asoud_account_level']?.toString().isNotEmpty == true
            ? json['asoud_account_level'].toString()
            : (json['is_group'] == 1 || json['is_group'] == true
                ? 'Group'
                : 'Subsidiary'),
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
  final String accountLevel;
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
        accountLevel,
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
    this.detailGroup = '',
    this.required = false,
    this.enabled = true,
    this.defaultFloatingDetail = '',
    this.validFrom = '',
    this.validTo = '',
  });

  factory AccountDetailRuleDraft.fromJson(Map<String, dynamic> json) =>
      AccountDetailRuleDraft(
        detailType: json['detail_type']?.toString() ?? '',
        detailGroup: json['detail_group']?.toString() ?? '',
        required: json['required'] == 1 || json['required'] == true,
        enabled: json['enabled'] == 1 || json['enabled'] == true,
        defaultFloatingDetail:
            json['default_floating_detail']?.toString() ?? '',
        validFrom: json['valid_from']?.toString() ?? '',
        validTo: json['valid_to']?.toString() ?? '',
      );

  final String detailType;
  final String detailGroup;
  final bool required;
  final bool enabled;
  final String defaultFloatingDetail;
  final String validFrom;
  final String validTo;

  AccountDetailRuleDraft copyWith({
    String? detailType,
    String? detailGroup,
    bool? required,
    bool? enabled,
    String? defaultFloatingDetail,
    String? validFrom,
    String? validTo,
  }) =>
      AccountDetailRuleDraft(
        detailType: detailType ?? this.detailType,
        detailGroup: detailGroup ?? this.detailGroup,
        required: required ?? this.required,
        enabled: enabled ?? this.enabled,
        defaultFloatingDetail:
            defaultFloatingDetail ?? this.defaultFloatingDetail,
        validFrom: validFrom ?? this.validFrom,
        validTo: validTo ?? this.validTo,
      );

  Map<String, dynamic> toJson() => {
        'detail_type': detailType,
        'detail_group': detailGroup.trim().isEmpty ? null : detailGroup,
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
        detailGroup,
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
    this.detailGroups = const [],
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
      detailGroups: (json['detail_groups'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FloatingDetailGroup.fromJson)
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
  final List<FloatingDetailGroup> detailGroups;
  final List<Map<String, dynamic>> floatingDetails;
  final List<ChartAccount> accounts;
  final Map<String, List<AccountDetailRuleDraft>> rules;

  @override
  List<Object?> get props => [
        company,
        detailTypes,
        detailGroups,
        floatingDetails,
        accounts,
        rules,
      ];
}

class ChartAccountDraft extends Equatable {
  const ChartAccountDraft({
    this.name = '',
    this.accountName = '',
    this.accountNumber = '',
    this.accountLevel = 'Subsidiary',
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
        accountLevel: account.accountLevel,
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
  final String accountLevel;
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
    String? accountLevel,
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
        accountLevel: accountLevel ?? this.accountLevel,
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
        'account_level': accountLevel,
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
        accountLevel,
        parentAccount,
        accountType,
        accountCurrency,
        isGroup,
        disabled,
        rules,
      ];
}

class FloatingDetailGroup extends Equatable {
  const FloatingDetailGroup({
    required this.name,
    required this.title,
    required this.code,
    required this.detailType,
    this.parentGroup = '',
    this.enabled = true,
  });

  factory FloatingDetailGroup.fromJson(Map<String, dynamic> json) =>
      FloatingDetailGroup(
        name: json['name']?.toString() ?? '',
        title: json['group_title']?.toString() ?? '',
        code: json['group_code']?.toString() ?? '',
        detailType: json['detail_type']?.toString() ?? '',
        parentGroup: json['parent_group']?.toString() ?? '',
        enabled: json['enabled'] == 1 || json['enabled'] == true,
      );

  final String name;
  final String title;
  final String code;
  final String detailType;
  final String parentGroup;
  final bool enabled;

  @override
  List<Object?> get props =>
      [name, title, code, detailType, parentGroup, enabled];
}

class FloatingDetailRecord extends Equatable {
  const FloatingDetailRecord({
    required this.name,
    required this.title,
    required this.detailType,
    required this.group,
    required this.code,
    this.referenceDoctype = '',
    this.referenceName = '',
    this.enabled = true,
    this.companyEnabled = true,
  });

  factory FloatingDetailRecord.fromJson(Map<String, dynamic> json) =>
      FloatingDetailRecord(
        name: json['name']?.toString() ?? '',
        title: json['detail_title']?.toString() ?? '',
        detailType: json['detail_type']?.toString() ?? '',
        group: json['detail_group']?.toString() ?? '',
        code: json['detail_code']?.toString() ?? '',
        referenceDoctype: json['reference_doctype']?.toString() ?? '',
        referenceName: json['reference_name']?.toString() ?? '',
        enabled: json['enabled'] == 1 || json['enabled'] == true,
        companyEnabled:
            json['company_enabled'] == 1 || json['company_enabled'] == true,
      );

  final String name;
  final String title;
  final String detailType;
  final String group;
  final String code;
  final String referenceDoctype;
  final String referenceName;
  final bool enabled;
  final bool companyEnabled;

  @override
  List<Object?> get props => [
        name,
        title,
        detailType,
        group,
        code,
        referenceDoctype,
        referenceName,
        enabled,
        companyEnabled,
      ];
}

class FloatingDetailManagementSnapshot extends Equatable {
  const FloatingDetailManagementSnapshot({
    required this.company,
    required this.holding,
    this.detailTypes = const [],
    this.groups = const [],
    this.details = const [],
  });

  factory FloatingDetailManagementSnapshot.fromJson(
    Map<String, dynamic> json,
  ) =>
      FloatingDetailManagementSnapshot(
        company: json['company']?.toString() ?? '',
        holding: json['holding']?.toString() ?? '',
        detailTypes: (json['detail_types'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        groups: (json['groups'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FloatingDetailGroup.fromJson)
            .toList(growable: false),
        details: (json['details'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FloatingDetailRecord.fromJson)
            .toList(growable: false),
      );

  final String company;
  final String holding;
  final List<String> detailTypes;
  final List<FloatingDetailGroup> groups;
  final List<FloatingDetailRecord> details;

  @override
  List<Object?> get props => [company, holding, detailTypes, groups, details];
}

class FloatingDetailGroupDraft extends Equatable {
  const FloatingDetailGroupDraft({
    this.name = '',
    this.title = '',
    this.code = '',
    this.detailType = 'Customer',
    this.parentGroup = '',
    this.enabled = true,
  });

  factory FloatingDetailGroupDraft.fromGroup(FloatingDetailGroup value) =>
      FloatingDetailGroupDraft(
        name: value.name,
        title: value.title,
        code: value.code,
        detailType: value.detailType,
        parentGroup: value.parentGroup,
        enabled: value.enabled,
      );

  final String name;
  final String title;
  final String code;
  final String detailType;
  final String parentGroup;
  final bool enabled;

  FloatingDetailGroupDraft copyWith({
    String? title,
    String? code,
    String? detailType,
    String? parentGroup,
    bool? enabled,
  }) =>
      FloatingDetailGroupDraft(
        name: name,
        title: title ?? this.title,
        code: code ?? this.code,
        detailType: detailType ?? this.detailType,
        parentGroup: parentGroup ?? this.parentGroup,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        'group_title': title,
        'group_code': code,
        'detail_type': detailType,
        'parent_group': parentGroup.isEmpty ? null : parentGroup,
        'enabled': enabled,
      };

  @override
  List<Object?> get props =>
      [name, title, code, detailType, parentGroup, enabled];
}

class FloatingDetailDraft extends Equatable {
  const FloatingDetailDraft({
    this.name = '',
    this.title = '',
    this.group = '',
    this.code = '',
    this.referenceDoctype = '',
    this.referenceName = '',
    this.enabled = true,
    this.companyEnabled = true,
  });

  factory FloatingDetailDraft.fromDetail(FloatingDetailRecord value) =>
      FloatingDetailDraft(
        name: value.name,
        title: value.title,
        group: value.group,
        code: value.code,
        referenceDoctype: value.referenceDoctype,
        referenceName: value.referenceName,
        enabled: value.enabled,
        companyEnabled: value.companyEnabled,
      );

  final String name;
  final String title;
  final String group;
  final String code;
  final String referenceDoctype;
  final String referenceName;
  final bool enabled;
  final bool companyEnabled;

  FloatingDetailDraft copyWith({
    String? title,
    String? group,
    String? code,
    String? referenceDoctype,
    String? referenceName,
    bool? enabled,
    bool? companyEnabled,
  }) =>
      FloatingDetailDraft(
        name: name,
        title: title ?? this.title,
        group: group ?? this.group,
        code: code ?? this.code,
        referenceDoctype: referenceDoctype ?? this.referenceDoctype,
        referenceName: referenceName ?? this.referenceName,
        enabled: enabled ?? this.enabled,
        companyEnabled: companyEnabled ?? this.companyEnabled,
      );

  Map<String, dynamic> toJson() => {
        if (name.isNotEmpty) 'name': name,
        'detail_title': title,
        'detail_group': group,
        'detail_code': code,
        'reference_doctype': referenceDoctype.isEmpty ? null : referenceDoctype,
        'reference_name': referenceName.isEmpty ? null : referenceName,
        'enabled': enabled,
        'company_enabled': companyEnabled,
      };

  @override
  List<Object?> get props => [
        name,
        title,
        group,
        code,
        referenceDoctype,
        referenceName,
        enabled,
        companyEnabled,
      ];
}
