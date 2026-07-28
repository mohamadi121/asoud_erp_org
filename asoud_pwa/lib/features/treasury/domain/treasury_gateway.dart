import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_snapshot.dart';

abstract interface class TreasuryGateway {
  Future<TreasurySnapshot> load(WorkContext context);
}
