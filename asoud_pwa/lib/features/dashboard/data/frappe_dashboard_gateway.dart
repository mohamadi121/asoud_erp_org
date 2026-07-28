import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_gateway.dart';
import 'package:asoud_pwa/features/dashboard/domain/dashboard_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeDashboardGateway implements DashboardGateway {
  const FrappeDashboardGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<DashboardSnapshot> load(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.dashboard_workspace',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException(
        'پاسخ داشبورد مدیریتی معتبر نیست.',
      );
    }
    return DashboardSnapshot.fromJson(message);
  }

  @override
  Future<void> markNotificationRead(String name) async {
    await _client.postForm(
      '/api/method/asoud_core.api.mark_dashboard_notification_read',
      {'name': name},
    );
  }
}
