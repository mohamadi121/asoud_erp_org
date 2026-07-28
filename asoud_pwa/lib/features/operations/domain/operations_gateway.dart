import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_snapshot.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class OperationsGateway {
  Future<OperationsSnapshot> load(WorkContext context);

  Future<OperationalWorkbench> loadWorkbench(WorkContext context);

  Future<List<String>> linkOptions({
    required String documentType,
    required String fieldname,
    String search = '',
    bool child = false,
  });

  Future<String> createDraft({
    required WorkContext context,
    required String documentType,
    required Map<String, dynamic> payload,
  });

  Future<void> transition({
    required String documentType,
    required String name,
    required String action,
    String reason = '',
  });
}
