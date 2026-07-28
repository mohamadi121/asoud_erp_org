import 'package:asoud_pwa/features/compliance/domain/compliance_snapshot.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class ComplianceGateway {
  Future<ComplianceSnapshot> load(WorkContext context);
}
