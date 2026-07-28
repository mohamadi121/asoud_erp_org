import 'package:asoud_pwa/features/compliance/domain/compliance_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses phase 14-16 readiness without promoting sandbox to production',
      () {
    final snapshot = ComplianceSnapshot.fromJson({
      'tax': {
        'configured': true,
        'environment': 'Sandbox',
        'queued': 2,
        'accepted': 4,
      },
      'bank': {
        'connections': {'Sandbox': 1},
        'unmatched_lines': 3,
      },
      'sayad': {'open_operations': 1},
      'consolidation': {'fx_policy': true, 'approved_rates': 3},
      'production_claimed': false,
    });

    expect(snapshot.taxEnvironment, 'Sandbox');
    expect(snapshot.bankConnections['Sandbox'], 1);
    expect(snapshot.approvedRates, 3);
    expect(snapshot.productionClaimed, isFalse);
  });
}
