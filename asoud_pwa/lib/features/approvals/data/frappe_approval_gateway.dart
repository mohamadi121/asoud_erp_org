import 'package:asoud_pwa/core/api/asoud_api_client.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

class FrappeApprovalGateway implements ApprovalGateway {
  const FrappeApprovalGateway(this._client);

  final AsoudApiClient _client;

  @override
  Future<ApprovalInbox> loadInbox(
    WorkContext context, {
    String view = 'incoming',
    String search = '',
    String status = '',
    int limit = 50,
  }) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.approval_inbox',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
        'view': view,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status.isNotEmpty) 'status': status,
        'limit': limit.toString(),
      },
    );
    return ApprovalInbox.fromJson(_messageMap(response));
  }

  @override
  Future<ApprovalDetail> loadDetail(String request) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.approval_request_detail',
      {'request': request},
    );
    return ApprovalDetail.fromJson(_messageMap(response));
  }

  @override
  Future<ApprovalDetail> act({
    required String request,
    required String action,
    required String comment,
    required String expectedVersion,
  }) async {
    final response = await _client.postForm(
      '/api/method/asoud_core.api.act_on_approval',
      {
        'request': request,
        'action': action,
        'comment': comment,
        'expected_version': expectedVersion,
        'idempotency_key': _requestKey('action'),
      },
    );
    return ApprovalDetail.fromJson(_messageMap(response));
  }

  @override
  Future<ApprovalDetail> start({
    required String sourceDoctype,
    required String sourceName,
  }) async {
    final response = await _client.postForm(
      '/api/method/asoud_core.api.start_approval_request',
      {
        'source_doctype': sourceDoctype,
        'source_name': sourceName,
        'idempotency_key': _requestKey('start'),
      },
    );
    return ApprovalDetail.fromJson(_messageMap(response));
  }

  @override
  Future<List<ApprovalPolicySummary>> loadPolicies(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.approval_policy_catalog',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
    final message = response['message'];
    if (message is! List<dynamic>) {
      throw const AsoudApiException(
        '\u067e\u0627\u0633\u062e \u0641\u0647\u0631\u0633\u062a \u0645\u0633\u06cc\u0631\u0647\u0627\u06cc \u062a\u0623\u06cc\u06cc\u062f \u0645\u0639\u062a\u0628\u0631 \u0646\u06cc\u0633\u062a.',
      );
    }
    return message
        .whereType<Map<String, dynamic>>()
        .map(ApprovalPolicySummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AccessOverview> loadAccess(WorkContext context) async {
    final response = await _client.getQuery(
      '/api/method/asoud_core.api.access_overview',
      {
        'company': context.company,
        if (context.branch != null) 'branch': context.branch!,
      },
    );
    return AccessOverview.fromJson(_messageMap(response));
  }

  @override
  Future<void> setAccess({
    required WorkContext context,
    required AccessGrantSummary grant,
    required bool enabled,
    required bool holdingManager,
  }) async {
    await _client.postForm(
      '/api/method/asoud_core.api.set_user_access',
      {
        'user': grant.user,
        'company': context.company,
        if (grant.branch != null) 'branch': grant.branch!,
        'enabled': enabled ? '1' : '0',
        'holding_manager': holdingManager ? '1' : '0',
        'idempotency_key': _requestKey('access'),
      },
    );
  }

  Map<String, dynamic> _messageMap(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is! Map<String, dynamic>) {
      throw const AsoudApiException(
        '\u067e\u0627\u0633\u062e \u06af\u0631\u062f\u0634 \u06a9\u0627\u0631 \u0645\u0639\u062a\u0628\u0631 \u0646\u06cc\u0633\u062a.',
      );
    }
    return message;
  }

  String _requestKey(String operation) =>
      'pwa-$operation-${DateTime.now().microsecondsSinceEpoch}';
}
