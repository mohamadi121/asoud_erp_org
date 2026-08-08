import 'package:asoud_pwa/features/approvals/domain/approval_gateway.dart';
import 'package:asoud_pwa/features/approvals/domain/approval_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ApprovalView { incoming, outgoing, history, policies, access }

extension ApprovalViewX on ApprovalView {
  String get apiValue => switch (this) {
        ApprovalView.incoming => 'incoming',
        ApprovalView.outgoing => 'outgoing',
        ApprovalView.history => 'history',
        ApprovalView.policies => 'policies',
        ApprovalView.access => 'access',
      };
}

enum ApprovalPhase { initial, loading, ready, failure }

class ApprovalState extends Equatable {
  const ApprovalState({
    this.phase = ApprovalPhase.initial,
    this.view = ApprovalView.incoming,
    this.query = '',
    this.status = '',
    this.inbox,
    this.policies = const [],
    this.policyWorkspace = const ApprovalPolicyWorkspace(),
    this.policySaving = false,
    this.access,
    this.detail,
    this.detailLoading = false,
    this.acting = false,
    this.error,
  });

  final ApprovalPhase phase;
  final ApprovalView view;
  final String query;
  final String status;
  final ApprovalInbox? inbox;
  final List<ApprovalPolicySummary> policies;
  final ApprovalPolicyWorkspace policyWorkspace;
  final bool policySaving;
  final AccessOverview? access;
  final ApprovalDetail? detail;
  final bool detailLoading;
  final bool acting;
  final String? error;

  ApprovalState copyWith({
    ApprovalPhase? phase,
    ApprovalView? view,
    String? query,
    String? status,
    ApprovalInbox? inbox,
    List<ApprovalPolicySummary>? policies,
    ApprovalPolicyWorkspace? policyWorkspace,
    bool? policySaving,
    AccessOverview? access,
    ApprovalDetail? detail,
    bool? detailLoading,
    bool? acting,
    String? error,
    bool clearError = false,
    bool clearDetail = false,
  }) =>
      ApprovalState(
        phase: phase ?? this.phase,
        view: view ?? this.view,
        query: query ?? this.query,
        status: status ?? this.status,
        inbox: inbox ?? this.inbox,
        policies: policies ?? this.policies,
        policyWorkspace: policyWorkspace ?? this.policyWorkspace,
        policySaving: policySaving ?? this.policySaving,
        access: access ?? this.access,
        detail: clearDetail ? null : detail ?? this.detail,
        detailLoading: detailLoading ?? this.detailLoading,
        acting: acting ?? this.acting,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [
        phase,
        view,
        query,
        status,
        inbox,
        policies,
        policyWorkspace,
        policySaving,
        access,
        detail,
        detailLoading,
        acting,
        error,
      ];
}

class ApprovalCubit extends Cubit<ApprovalState> {
  ApprovalCubit({
    required ApprovalGateway gateway,
    required WorkContext context,
    ApprovalView initialView = ApprovalView.incoming,
  })  : _gateway = gateway,
        _context = context,
        super(ApprovalState(view: initialView));

  final ApprovalGateway _gateway;
  final WorkContext _context;

  Future<void> load() async {
    emit(state.copyWith(
      phase: ApprovalPhase.loading,
      clearError: true,
      clearDetail: true,
    ));
    try {
      switch (state.view) {
        case ApprovalView.policies:
          final workspace = await _gateway.loadPolicyWorkspace(_context);
          emit(state.copyWith(
            phase: ApprovalPhase.ready,
            policies: workspace.policies,
            policyWorkspace: workspace,
            clearError: true,
          ));
        case ApprovalView.access:
          final access = await _gateway.loadAccess(_context);
          emit(state.copyWith(
            phase: ApprovalPhase.ready,
            access: access,
            clearError: true,
          ));
        case ApprovalView.incoming:
        case ApprovalView.outgoing:
        case ApprovalView.history:
          final inbox = await _gateway.loadInbox(
            _context,
            view: state.view.apiValue,
            search: state.query,
            status: state.status,
          );
          emit(state.copyWith(
            phase: ApprovalPhase.ready,
            inbox: inbox,
            clearError: true,
          ));
      }
    } on Object catch (error) {
      emit(state.copyWith(
        phase: ApprovalPhase.failure,
        error: error.toString(),
      ));
    }
  }

  Future<void> changeView(ApprovalView view) async {
    if (view == state.view && state.phase == ApprovalPhase.ready) return;
    emit(state.copyWith(
      view: view,
      status: '',
      clearDetail: true,
      clearError: true,
    ));
    await load();
  }

  Future<void> applySearch(String query) async {
    emit(state.copyWith(query: query.trim(), clearDetail: true));
    await load();
  }

  Future<void> applyStatus(String status) async {
    emit(state.copyWith(status: status, clearDetail: true));
    await load();
  }

  Future<void> openDetail(String request) async {
    emit(state.copyWith(
      detailLoading: true,
      clearDetail: true,
      clearError: true,
    ));
    try {
      final detail = await _gateway.loadDetail(request);
      emit(state.copyWith(
        detail: detail,
        detailLoading: false,
        clearError: true,
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        detailLoading: false,
        error: error.toString(),
      ));
    }
  }

  void closeDetail() => emit(state.copyWith(clearDetail: true));

  Future<bool> act(String action, String comment) async {
    final current = state.detail;
    if (current == null || state.acting) return false;
    emit(state.copyWith(acting: true, clearError: true));
    try {
      final updated = await _gateway.act(
        request: current.summary.name,
        action: action,
        comment: comment,
        expectedVersion: current.summary.version,
      );
      final inbox = await _gateway.loadInbox(
        _context,
        view: state.view.apiValue,
        search: state.query,
        status: state.status,
      );
      emit(state.copyWith(
        acting: false,
        detail: updated,
        inbox: inbox,
        clearError: true,
      ));
      return true;
    } on Object catch (error) {
      emit(state.copyWith(acting: false, error: error.toString()));
      return false;
    }
  }

  Future<bool> start(String sourceDoctype, String sourceName) async {
    emit(state.copyWith(acting: true, clearError: true));
    try {
      final detail = await _gateway.start(
        sourceDoctype: sourceDoctype,
        sourceName: sourceName,
      );
      emit(state.copyWith(
        view: ApprovalView.outgoing,
        status: '',
        query: '',
        detail: detail,
        acting: false,
      ));
      await load();
      return true;
    } on Object catch (error) {
      emit(state.copyWith(acting: false, error: error.toString()));
      return false;
    }
  }

  Future<bool> savePolicy(ApprovalPolicyDraft draft) async {
    if (state.policySaving) return false;
    emit(state.copyWith(policySaving: true, clearError: true));
    try {
      await _gateway.savePolicy(_context, draft);
      final workspace = await _gateway.loadPolicyWorkspace(_context);
      emit(state.copyWith(
        phase: ApprovalPhase.ready,
        policySaving: false,
        policies: workspace.policies,
        policyWorkspace: workspace,
        clearError: true,
      ));
      return true;
    } on Object catch (error) {
      emit(state.copyWith(policySaving: false, error: error.toString()));
      return false;
    }
  }
}
