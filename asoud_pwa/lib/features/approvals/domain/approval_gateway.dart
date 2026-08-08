import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';

abstract interface class ApprovalGateway {
  Future<ApprovalInbox> loadInbox(
    WorkContext context, {
    String view = 'incoming',
    String search = '',
    String status = '',
    int limit = 50,
  });

  Future<ApprovalDetail> loadDetail(String request);

  Future<ApprovalDetail> act({
    required String request,
    required String action,
    required String comment,
    required String expectedVersion,
  });

  Future<ApprovalDetail> start({
    required String sourceDoctype,
    required String sourceName,
  });

  Future<List<ApprovalPolicySummary>> loadPolicies(WorkContext context);

  Future<ApprovalPolicyWorkspace> loadPolicyWorkspace(WorkContext context);

  Future<ApprovalPolicySummary> savePolicy(
    WorkContext context,
    ApprovalPolicyDraft draft,
  );

  Future<AccessOverview> loadAccess(WorkContext context);

  Future<void> setAccess({
    required WorkContext context,
    required AccessGrantSummary grant,
    required bool enabled,
    required bool holdingManager,
  });
}
