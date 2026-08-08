import 'package:equatable/equatable.dart';

class AccountingSettings extends Equatable {
  const AccountingSettings({
    required this.company,
    required this.setupStatus,
    this.coaTemplate,
    this.baseCurrency,
    this.amountInputUnit,
    this.calendarDisplay,
    this.timezone,
    this.setupVersion,
  });

  factory AccountingSettings.fromJson(Map<String, dynamic> json) =>
      AccountingSettings(
        company: json['company']?.toString() ?? '',
        setupStatus: json['setup_status']?.toString() ?? 'Pending',
        coaTemplate: json['coa_template']?.toString(),
        baseCurrency: json['base_currency']?.toString(),
        amountInputUnit: json['amount_input_unit']?.toString(),
        calendarDisplay: json['calendar_display']?.toString(),
        timezone: json['timezone']?.toString(),
        setupVersion: json['setup_version']?.toString(),
      );

  final String company;
  final String setupStatus;
  final String? coaTemplate;
  final String? baseCurrency;
  final String? amountInputUnit;
  final String? calendarDisplay;
  final String? timezone;
  final String? setupVersion;

  bool get isReady => setupStatus == 'Completed';

  @override
  List<Object?> get props => [
        company,
        setupStatus,
        coaTemplate,
        baseCurrency,
        amountInputUnit,
        calendarDisplay,
        timezone,
        setupVersion,
      ];
}

class TrialBalanceRow extends Equatable {
  const TrialBalanceRow({
    required this.account,
    required this.accountNumber,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory TrialBalanceRow.fromJson(Map<String, dynamic> json) =>
      TrialBalanceRow(
        account: json['account']?.toString() ?? '',
        accountNumber: json['account_number']?.toString() ?? '',
        debit: json['debit']?.toString() ?? '0',
        credit: json['credit']?.toString() ?? '0',
        balance: json['balance']?.toString() ?? '0',
      );

  final String account;
  final String accountNumber;
  final String debit;
  final String credit;
  final String balance;

  @override
  List<Object?> get props => [account, accountNumber, debit, credit, balance];
}

class AccountSummary extends Equatable {
  const AccountSummary({
    required this.name,
    required this.number,
    required this.title,
    required this.rootType,
    required this.isGroup,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) => AccountSummary(
        name: json['name']?.toString() ?? '',
        number: json['account_number']?.toString() ?? '',
        title: json['account_name']?.toString() ?? '',
        rootType: json['root_type']?.toString() ?? '',
        isGroup: json['is_group'] == 1 || json['is_group'] == true,
      );

  final String name;
  final String number;
  final String title;
  final String rootType;
  final bool isGroup;

  @override
  List<Object?> get props => [name, number, title, rootType, isGroup];
}

class NumberingCandidate extends Equatable {
  const NumberingCandidate({
    required this.name,
    required this.postingDate,
    required this.sourceType,
    required this.sourceName,
    required this.temporaryNumber,
  });

  factory NumberingCandidate.fromJson(Map<String, dynamic> json) =>
      NumberingCandidate(
        name: json['name']?.toString() ?? '',
        postingDate: json['posting_date']?.toString() ?? '',
        sourceType: json['source_doctype']?.toString() ?? '',
        sourceName: json['source_name']?.toString() ?? '',
        temporaryNumber: json['temporary_number']?.toString() ?? '',
      );

  final String name;
  final String postingDate;
  final String sourceType;
  final String sourceName;
  final String temporaryNumber;

  @override
  List<Object?> get props =>
      [name, postingDate, sourceType, sourceName, temporaryNumber];
}

class FiscalYearOption extends Equatable {
  const FiscalYearOption({
    required this.name,
    required this.fromDate,
    required this.toDate,
  });

  factory FiscalYearOption.fromJson(Map<String, dynamic> json) =>
      FiscalYearOption(
        name: json['name']?.toString() ?? '',
        fromDate: json['year_start_date']?.toString() ?? '',
        toDate: json['year_end_date']?.toString() ?? '',
      );

  final String name;
  final String fromDate;
  final String toDate;

  @override
  List<Object?> get props => [name, fromDate, toDate];
}

class NumberingWorkspace extends Equatable {
  const NumberingWorkspace({
    this.company = '',
    this.postingDate = '',
    this.candidates = const [],
    this.availableDates = const [],
    this.fiscalYears = const [],
    this.recentConsolidations = const [],
  });

  factory NumberingWorkspace.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) =>
        (json[key] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);

    return NumberingWorkspace(
      company: json['company']?.toString() ?? '',
      postingDate: json['posting_date']?.toString() ?? '',
      candidates: rows('candidates').map(NumberingCandidate.fromJson).toList(),
      availableDates: (json['available_dates'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      fiscalYears: rows('fiscal_years').map(FiscalYearOption.fromJson).toList(),
      recentConsolidations: rows('recent_consolidations'),
    );
  }

  final String company;
  final String postingDate;
  final List<NumberingCandidate> candidates;
  final List<String> availableDates;
  final List<FiscalYearOption> fiscalYears;
  final List<Map<String, dynamic>> recentConsolidations;

  @override
  List<Object?> get props => [
        company,
        postingDate,
        candidates,
        availableDates,
        fiscalYears,
        recentConsolidations,
      ];
}
