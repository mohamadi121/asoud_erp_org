import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/compliance/domain/compliance_gateway.dart';
import 'package:asoud_pwa/features/compliance/domain/compliance_snapshot.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeComplianceGateway implements ComplianceGateway {
  const FrappeComplianceGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<ComplianceSnapshot> load(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.compliance_connectivity_dashboard',
      {'company': context.company},
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ داشبورد انطباق معتبر نیست.');
    }
    return ComplianceSnapshot.fromJson(message);
  }
}
