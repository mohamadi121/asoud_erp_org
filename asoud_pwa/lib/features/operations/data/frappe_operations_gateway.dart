import 'dart:convert';
import 'dart:math';

import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/operations/domain/operational_workbench.dart';
import 'package:asoud_pwa/features/operations/domain/operations_gateway.dart';
import 'package:asoud_pwa/features/operations/domain/operations_snapshot.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeOperationsGateway implements OperationsGateway {
  const FrappeOperationsGateway(this._client);

  final AsoudApiClient _client;

  String _idempotencyKey() {
    final random = Random.secure();
    final entropy = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'pwa-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  @override
  Future<OperationsSnapshot> load(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.operational_dashboard',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException(
        '\u067e\u0627\u0633\u062e \u062f\u0627\u0634\u0628\u0648\u0631\u062f \u0639\u0645\u0644\u06cc\u0627\u062a\u06cc \u0645\u0639\u062a\u0628\u0631 \u0646\u06cc\u0633\u062a.',
      );
    }
    return OperationsSnapshot.fromJson(message);
  }

  @override
  Future<OperationalWorkbench> loadWorkbench(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.operational_workbench',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException('پاسخ میزکار عملیاتی معتبر نیست.');
    }
    return OperationalWorkbench.fromJson(message);
  }

  @override
  Future<List<String>> linkOptions({
    required String documentType,
    required String fieldname,
    String search = '',
    bool child = false,
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.operational_link_options',
      {
        'document_type': documentType,
        'fieldname': fieldname,
        'search': search,
        'child': child ? '1' : '0',
      },
    );
    final message = response['message'];
    if (message is! List) {
      throw const AsoudApiException('گزینه‌های فیلد معتبر نیست.');
    }
    return message
        .whereType<Map>()
        .map((item) => item['value']?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<String> createDraft({
    required WorkContext context,
    required String documentType,
    required Map<String, dynamic> payload,
  }) async {
    final requestKey = _idempotencyKey();
    final safePayload = Map<String, dynamic>.from(payload);
    if (documentType == 'ASOUD Intercompany Transfer') {
      safePayload['idempotency_key'] = requestKey;
    }
    final response = await _client.postForm(
      '/api/method/asoud_core.api.create_operational_draft',
      {
        'document_type': documentType,
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
        'payload': jsonEncode(safePayload),
        'idempotency_key': requestKey,
      },
    );
    final message = response['message'];
    if (message is! Map<String, dynamic> || message['name'] == null) {
      throw const AsoudApiException('پیش‌نویس عملیاتی ایجاد نشد.');
    }
    return message['name'].toString();
  }

  @override
  Future<List<String>> eligibleFloatingDetails({
    required WorkContext context,
    required String account,
    String search = '',
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_iran.api.eligible_floating_details',
      {'company': context.company, 'account': account, 'query': search},
    );
    final message = response['message'];
    if (message is! List) {
      throw const AsoudApiException('پاسخ تفصیلی‌های مجاز معتبر نیست.');
    }
    return message
        .whereType<Map>()
        .map((item) => item['name']?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> transition({
    required String documentType,
    required String name,
    required String action,
    String reason = '',
  }) async {
    final path = action == 'approve_source'
        ? '/api/method/asoud_core.api.approve_intercompany_source'
        : action == 'accept_destination'
            ? '/api/method/asoud_core.api.accept_intercompany_destination'
            : '/api/method/asoud_core.api.transition_operational_document';
    await _client.postForm(
      path,
      {
        if (action == 'approve_source' || action == 'accept_destination')
          'transfer': name
        else ...{
          'document_type': documentType,
          'name': name,
          'action': action,
          'reason': reason,
        },
        'idempotency_key': _idempotencyKey(),
      },
    );
  }
}
