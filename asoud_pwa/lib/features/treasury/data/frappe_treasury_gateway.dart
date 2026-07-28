import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_gateway.dart';
import 'package:asoud_pwa/features/treasury/domain/treasury_snapshot.dart';

class FrappeTreasuryGateway implements TreasuryGateway {
  const FrappeTreasuryGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<TreasurySnapshot> load(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.treasury_dashboard',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ داشبورد خزانه‌داری معتبر نیست.');
    }
    return TreasurySnapshot.fromJson(message);
  }
}
