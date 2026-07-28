class ComplianceSnapshot {
  const ComplianceSnapshot({
    required this.taxConfigured,
    required this.taxEnvironment,
    required this.taxQueued,
    required this.taxAccepted,
    required this.bankConnections,
    required this.unmatchedLines,
    required this.openSayadOperations,
    required this.fxPolicy,
    required this.approvedRates,
    required this.productionClaimed,
  });

  factory ComplianceSnapshot.fromJson(Map<String, dynamic> json) {
    final tax = json['tax'] as Map<String, dynamic>? ?? const {};
    final bank = json['bank'] as Map<String, dynamic>? ?? const {};
    final sayad = json['sayad'] as Map<String, dynamic>? ?? const {};
    final consolidation =
        json['consolidation'] as Map<String, dynamic>? ?? const {};
    final connections =
        bank['connections'] as Map<String, dynamic>? ?? const {};
    return ComplianceSnapshot(
      taxConfigured: tax['configured'] == true,
      taxEnvironment: tax['environment']?.toString(),
      taxQueued: (tax['queued'] as num?)?.toInt() ?? 0,
      taxAccepted: (tax['accepted'] as num?)?.toInt() ?? 0,
      bankConnections: connections.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      unmatchedLines: (bank['unmatched_lines'] as num?)?.toInt() ?? 0,
      openSayadOperations: (sayad['open_operations'] as num?)?.toInt() ?? 0,
      fxPolicy: consolidation['fx_policy'] == true,
      approvedRates: (consolidation['approved_rates'] as num?)?.toInt() ?? 0,
      productionClaimed: json['production_claimed'] == true,
    );
  }

  final bool taxConfigured;
  final String? taxEnvironment;
  final int taxQueued;
  final int taxAccepted;
  final Map<String, int> bankConnections;
  final int unmatchedLines;
  final int openSayadOperations;
  final bool fxPolicy;
  final int approvedRates;
  final bool productionClaimed;
}
