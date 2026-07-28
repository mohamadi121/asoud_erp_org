import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeOrganizationGateway implements OrganizationGateway {
  const FrappeOrganizationGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<OrganizationSnapshot> load(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.organization_settings_snapshot',
      {'company': context.company},
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ تنظیمات سازمانی معتبر نیست.');
    }
    return OrganizationSnapshot.fromJson(message);
  }

  @override
  Future<void> save(OrganizationDraft draft) async {
    await _client.postForm(
      '/api/method/asoud_core.api.save_organization_unit',
      {
        'payload': jsonEncode(draft.toJson()),
        'idempotency_key':
            'organization-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
  }
}
