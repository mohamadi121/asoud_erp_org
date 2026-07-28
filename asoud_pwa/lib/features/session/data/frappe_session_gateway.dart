import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/session/domain/session_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeSessionGateway implements SessionGateway {
  const FrappeSessionGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<List<WorkContext>> login(
      {required String username, required String password}) async {
    await _client
        .postForm('/api/method/login', {'usr': username, 'pwd': password});
    final security = await _client.get(
      '/api/method/asoud_core.api.session_security_context',
    );
    final securityMessage = security['message'];
    if (securityMessage is! Map<String, dynamic> ||
        securityMessage['csrf_token'] == null) {
      throw const AsoudApiException('نشست امن کاربر ایجاد نشد.');
    }
    _client.setCsrfToken(securityMessage['csrf_token'].toString());
    final response =
        await _client.get('/api/method/asoud_core.api.accessible_contexts');
    final message = response['message'];
    if (message is! List) {
      throw const AsoudApiException(
        '\u0641\u0647\u0631\u0633\u062a \u0634\u0631\u06a9\u062a\u200c\u0647\u0627 \u0648 \u0634\u0639\u0628\u0647\u200c\u0647\u0627 \u0645\u0639\u062a\u0628\u0631 \u0646\u06cc\u0633\u062a.',
      );
    }
    return message
        .whereType<Map>()
        .map((item) => WorkContext.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<void> activateContext(WorkContext context) async {
    await _client.postForm(
      '/api/method/asoud_core.api.set_active_context',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
  }
}
