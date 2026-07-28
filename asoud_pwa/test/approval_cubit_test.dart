import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/approvals/presentation/bloc/approval_cubit.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads incoming and routes history with search and status', () async {
    final gateway = _FakeApprovalGateway();
    final cubit = ApprovalCubit(
      gateway: gateway,
      context: const WorkContext(company: 'A', branch: 'A-HQ'),
    );

    await cubit.load();
    expect(cubit.state.phase, ApprovalPhase.ready);
    expect(cubit.state.inbox?.incomingCount, 2);
    expect(gateway.lastView, 'incoming');

    await cubit.changeView(ApprovalView.history);
    await cubit.applySearch('PAY-1');
    await cubit.applyStatus('Approved');

    expect(gateway.lastView, 'history');
    expect(gateway.lastSearch, 'PAY-1');
    expect(gateway.lastStatus, 'Approved');
    await cubit.close();
  });

  test('loads detail and performs an optimistic approval action', () async {
    final gateway = _FakeApprovalGateway();
    final cubit = ApprovalCubit(
      gateway: gateway,
      context: const WorkContext(company: 'A'),
    );
    await cubit.load();

    await cubit.openDetail('APR-1');
    expect(cubit.state.detail?.summary.name, 'APR-1');

    final accepted = await cubit.act('Approve', '');

    expect(accepted, isTrue);
    expect(gateway.lastAction, 'Approve');
    expect(gateway.lastExpectedVersion, 'v1');
    expect(cubit.state.detail?.summary.status, 'Approved');
    await cubit.close();
  });
}

class _FakeApprovalGateway implements ApprovalGateway {
  String lastView = '';
  String lastSearch = '';
  String lastStatus = '';
  String lastAction = '';
  String lastExpectedVersion = '';

  @override
  Future<ApprovalInbox> loadInbox(
    WorkContext context, {
    String view = 'incoming',
    String search = '',
    String status = '',
    int limit = 50,
  }) async {
    lastView = view;
    lastSearch = search;
    lastStatus = status;
    return const ApprovalInbox(
      items: [],
      incomingCount: 2,
      outgoingCount: 3,
      historyCount: 4,
    );
  }

  @override
  Future<ApprovalDetail> loadDetail(String request) async =>
      _detail(status: 'Pending', canAct: true, version: 'v1');

  @override
  Future<ApprovalDetail> act({
    required String request,
    required String action,
    required String comment,
    required String expectedVersion,
  }) async {
    lastAction = action;
    lastExpectedVersion = expectedVersion;
    return _detail(status: 'Approved', canAct: false, version: 'v2');
  }

  @override
  Future<ApprovalDetail> start({
    required String sourceDoctype,
    required String sourceName,
  }) async =>
      _detail(status: 'Pending', canAct: false, version: 'v1');

  @override
  Future<List<ApprovalPolicySummary>> loadPolicies(
    WorkContext context,
  ) async =>
      const [];

  @override
  Future<AccessOverview> loadAccess(WorkContext context) async =>
      const AccessOverview(users: []);

  @override
  Future<void> setAccess({
    required WorkContext context,
    required AccessGrantSummary grant,
    required bool enabled,
    required bool holdingManager,
  }) async {}
}

ApprovalDetail _detail({
  required String status,
  required bool canAct,
  required String version,
}) =>
    ApprovalDetail(
      summary: ApprovalSummary(
        name: 'APR-1',
        sourceDoctype: 'Payment Entry',
        sourceName: 'PAY-1',
        company: 'A',
        policy: 'POL-1',
        amount: 100,
        requestedBy: 'maker@example.com',
        requestedOn: '2026-07-27 08:00:00',
        status: status,
        currentSequence: 1,
        version: version,
      ),
      canAct: canAct,
      stages: const [],
      actions: const [],
    );
