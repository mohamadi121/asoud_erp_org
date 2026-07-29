import 'dart:convert';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/parties/domain/party_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappePartyGateway implements PartyGateway {
  const FrappePartyGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<PartySnapshot> load(
    WorkContext context, {
    String search = '',
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.party_management_snapshot',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PartySnapshot.fromJson(_message(response));
  }

  @override
  Future<Map<String, String>> previewCodes(
    WorkContext context,
    Set<String> roles,
  ) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.party_code_preview',
      {
        'company': context.company,
        'roles': jsonEncode(roles.toList(growable: false)),
      },
    );
    return _message(response)
        .map((key, value) => MapEntry(key, value.toString()));
  }

  @override
  Future<PartyProfile> loadDetail(WorkContext context, String name) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.party_management_detail',
      {'company': context.company, 'name': name},
    );
    return PartyProfile.fromJson(_message(response));
  }

  @override
  Future<void> save(WorkContext context, PartyDraft draft) async {
    await _client.postForm(
      '/api/method/asoud_core.api.save_party_identity',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
        'payload': jsonEncode(draft.toJson()),
        'idempotency_key': 'party-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
  }

  Map<String, dynamic> _message(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ مدیریت اشخاص معتبر نیست.');
    }
    return message;
  }
}
