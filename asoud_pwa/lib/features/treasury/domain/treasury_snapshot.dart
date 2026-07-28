import 'package:equatable/equatable.dart';

class TreasuryAccountBalance extends Equatable {
  const TreasuryAccountBalance({
    required this.name,
    required this.title,
    required this.type,
    required this.balance,
    this.branch,
  });

  factory TreasuryAccountBalance.fromJson(Map<String, dynamic> json) =>
      TreasuryAccountBalance(
        name: json['name']?.toString() ?? '',
        title: json['account_title']?.toString() ?? '',
        type: json['treasury_type']?.toString() ?? '',
        branch: json['branch']?.toString(),
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );

  final String name;
  final String title;
  final String type;
  final String? branch;
  final double balance;

  @override
  List<Object?> get props => [name, title, type, branch, balance];
}

class TreasurySnapshot extends Equatable {
  const TreasurySnapshot({
    required this.asOfDate,
    required this.bank,
    required this.cash,
    required this.pettyCash,
    required this.accounts,
    required this.cheques,
    required this.unsettledPettyCashClaims,
  });

  factory TreasurySnapshot.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : const <String, dynamic>{};
    final accountRows =
        json['accounts'] is List ? json['accounts'] as List : const <dynamic>[];
    final chequeRows = json['cheques'] is Map
        ? Map<String, dynamic>.from(json['cheques'] as Map)
        : const <String, dynamic>{};
    return TreasurySnapshot(
      asOfDate: json['as_of_date']?.toString() ?? '',
      bank: (totals['Bank'] as num?)?.toDouble() ?? 0,
      cash: (totals['Cash'] as num?)?.toDouble() ?? 0,
      pettyCash: (totals['Petty Cash'] as num?)?.toDouble() ?? 0,
      accounts: accountRows
          .whereType<Map>()
          .map((row) =>
              TreasuryAccountBalance.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      cheques: chequeRows.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0),
      ),
      unsettledPettyCashClaims:
          (json['unsettled_petty_cash_claims'] as num?)?.toInt() ?? 0,
    );
  }

  final String asOfDate;
  final double bank;
  final double cash;
  final double pettyCash;
  final List<TreasuryAccountBalance> accounts;
  final Map<String, double> cheques;
  final int unsettledPettyCashClaims;

  @override
  List<Object?> get props => [
        asOfDate,
        bank,
        cash,
        pettyCash,
        accounts,
        cheques,
        unsettledPettyCashClaims,
      ];
}
