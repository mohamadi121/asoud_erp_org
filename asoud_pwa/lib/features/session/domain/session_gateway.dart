import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class SessionGateway {
  Future<List<WorkContext>> login(
      {required String username, required String password});

  Future<void> activateContext(WorkContext context);
}
