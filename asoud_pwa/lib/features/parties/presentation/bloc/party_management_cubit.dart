import 'package:asoud_pwa/features/parties/domain/party_gateway.dart';
import 'package:asoud_pwa/features/parties/domain/party_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PartyPhase { initial, loading, ready, saving, failure }

class PartyManagementState extends Equatable {
  const PartyManagementState({
    this.phase = PartyPhase.initial,
    this.snapshot = const PartySnapshot(),
    this.draft,
    this.profile,
    this.codePreview = const {},
    this.error,
  });

  final PartyPhase phase;
  final PartySnapshot snapshot;
  final PartyDraft? draft;
  final PartyProfile? profile;
  final Map<String, String> codePreview;
  final String? error;

  PartyManagementState copyWith({
    PartyPhase? phase,
    PartySnapshot? snapshot,
    PartyDraft? draft,
    PartyProfile? profile,
    Map<String, String>? codePreview,
    String? error,
    bool clearDraft = false,
    bool clearProfile = false,
    bool clearError = false,
  }) =>
      PartyManagementState(
        phase: phase ?? this.phase,
        snapshot: snapshot ?? this.snapshot,
        draft: clearDraft ? null : draft ?? this.draft,
        profile: clearProfile ? null : profile ?? this.profile,
        codePreview: codePreview ?? this.codePreview,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props =>
      [phase, snapshot, draft, profile, codePreview, error];
}

class PartyManagementCubit extends Cubit<PartyManagementState> {
  PartyManagementCubit(this.gateway, this.context)
      : super(const PartyManagementState());

  final PartyGateway gateway;
  final WorkContext context;

  Future<void> load({String search = ''}) async {
    emit(state.copyWith(phase: PartyPhase.loading, clearError: true));
    try {
      emit(state.copyWith(
        phase: PartyPhase.ready,
        snapshot: await gateway.load(context, search: search),
      ));
    } catch (error) {
      emit(state.copyWith(phase: PartyPhase.failure, error: '$error'));
    }
  }

  Future<void> create() async {
    const draft = PartyDraft();
    emit(state.copyWith(
      draft: draft,
      codePreview: const {},
      clearProfile: true,
    ));
    await _refreshCodes();
  }

  void cancel() => emit(state.copyWith(clearDraft: true));

  Future<void> openProfile(String name) async {
    emit(state.copyWith(phase: PartyPhase.loading, clearError: true));
    try {
      emit(state.copyWith(
        phase: PartyPhase.ready,
        profile: await gateway.loadDetail(context, name),
      ));
    } catch (error) {
      emit(state.copyWith(phase: PartyPhase.failure, error: '$error'));
    }
  }

  void closeProfile() => emit(state.copyWith(clearProfile: true));

  void editProfile() {
    final profile = state.profile;
    if (profile == null) return;
    emit(state.copyWith(
      draft: profile.draft,
      codePreview: profile.codes,
      clearProfile: true,
    ));
  }

  void update(PartyDraft draft) => emit(state.copyWith(draft: draft));

  Future<void> toggleRole(String role) async {
    final draft = state.draft;
    if (draft == null) return;
    final roles = {...draft.roles};
    final balances = {...draft.openingBalances};
    final policies = {...draft.companyPolicies};
    if (!roles.remove(role)) {
      roles.add(role);
      balances.putIfAbsent(role, () => OpeningBalanceDraft(role: role));
      if (role == 'Customer' || role == 'Supplier') {
        policies.putIfAbsent(role, () => CompanyPartyPolicy(role: role));
      }
    } else {
      balances.remove(role);
      policies.remove(role);
    }
    if (roles.isEmpty) return;
    emit(state.copyWith(
      draft: draft.copyWith(
        roles: roles,
        openingBalances: balances,
        companyPolicies: policies,
      ),
    ));
    await _refreshCodes();
  }

  void updateCompanyPolicy(String role, CompanyPartyPolicy policy) {
    final draft = state.draft;
    if (draft == null || !draft.roles.contains(role)) return;
    emit(state.copyWith(
      draft: draft.copyWith(
        companyPolicies: {...draft.companyPolicies, role: policy},
      ),
    ));
  }

  void updateOpening(
    String role, {
    String? stateValue,
    double? amount,
  }) {
    final draft = state.draft;
    if (draft == null) return;
    final balances = {...draft.openingBalances};
    balances[role] = (balances[role] ?? OpeningBalanceDraft(role: role))
        .copyWith(balanceState: stateValue, amount: amount);
    emit(state.copyWith(
      draft: draft.copyWith(openingBalances: balances),
    ));
  }

  Future<void> save() async {
    final draft = state.draft;
    if (draft == null) return;
    emit(state.copyWith(phase: PartyPhase.saving, clearError: true));
    try {
      await gateway.save(context, draft);
      final snapshot = await gateway.load(context);
      emit(state.copyWith(
        phase: PartyPhase.ready,
        snapshot: snapshot,
        clearDraft: true,
        clearProfile: true,
      ));
    } catch (error) {
      emit(state.copyWith(phase: PartyPhase.failure, error: '$error'));
    }
  }

  Future<void> _refreshCodes() async {
    final roles = state.draft?.roles;
    if (roles == null) return;
    try {
      emit(state.copyWith(
        codePreview: await gateway.previewCodes(context, roles),
      ));
    } catch (error) {
      emit(state.copyWith(error: '$error'));
    }
  }
}
