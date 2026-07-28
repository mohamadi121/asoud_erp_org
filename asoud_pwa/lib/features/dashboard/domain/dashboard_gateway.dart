import 'package:asoud_pwa/features/dashboard/domain/dashboard_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class DashboardGateway {
  Future<DashboardSnapshot> load(WorkContext context);

  Future<void> markNotificationRead(String name);
}
