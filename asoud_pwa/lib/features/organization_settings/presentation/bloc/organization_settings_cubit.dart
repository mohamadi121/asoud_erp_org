import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum OrganizationPhase { initial, loading, ready, saving, failure }

enum SettingsView { dashboard, structure, financial }

class OrganizationSettingsState extends Equatable {
  const OrganizationSettingsState({
    this.phase = OrganizationPhase.initial,
    this.view = SettingsView.dashboard,
    this.snapshot = const OrganizationSnapshot(),
    this.draft,
    this.error,
  });

  final OrganizationPhase phase;
  final SettingsView view;
  final OrganizationSnapshot snapshot;
  final OrganizationDraft? draft;
  final String? error;

  OrganizationSettingsState copyWith({
    OrganizationPhase? phase,
    SettingsView? view,
    OrganizationSnapshot? snapshot,
    OrganizationDraft? draft,
    String? error,
    bool clearDraft = false,
    bool clearError = false,
  }) =>
      OrganizationSettingsState(
        phase: phase ?? this.phase,
        view: view ?? this.view,
        snapshot: snapshot ?? this.snapshot,
        draft: clearDraft ? null : draft ?? this.draft,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [phase, view, snapshot, draft, error];
}

class OrganizationSettingsCubit extends Cubit<OrganizationSettingsState> {
  OrganizationSettingsCubit(this._gateway, this._context)
      : super(const OrganizationSettingsState());

  final OrganizationGateway _gateway;
  final WorkContext _context;

  Future<void> load() async {
    emit(state.copyWith(phase: OrganizationPhase.loading, clearError: true));
    try {
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        snapshot: await _gateway.load(_context),
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.failure,
        error: error.toString(),
      ));
    }
  }

  void show(SettingsView view) => emit(state.copyWith(view: view));

  void start(OrganizationUnitKind kind) => emit(state.copyWith(
        draft: OrganizationDraft(kind: kind),
        clearError: true,
      ));

  void update(String key, String value) {
    final draft = state.draft;
    if (draft == null) return;
    emit(state.copyWith(
      draft: draft.copyWith(values: {...draft.values, key: value}),
    ));
  }

  void next() {
    final draft = state.draft;
    if (draft == null) return;
    final missing = _missingRequired(draft);
    if (missing.isNotEmpty) {
      emit(state.copyWith(
          error: 'فیلدهای الزامی را تکمیل کنید: ${missing.join('، ')}'));
      return;
    }
    emit(state.copyWith(
      draft: draft.copyWith(step: draft.step + 1),
      clearError: true,
    ));
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step == 0) return;
    emit(state.copyWith(draft: draft.copyWith(step: draft.step - 1)));
  }

  void cancel() => emit(state.copyWith(clearDraft: true, clearError: true));

  Future<bool> save() async {
    final draft = state.draft;
    if (draft == null) return false;
    final missing = _missingRequired(draft);
    if (missing.isNotEmpty) {
      emit(state.copyWith(
          error: 'فیلدهای الزامی را تکمیل کنید: ${missing.join('، ')}'));
      return false;
    }
    emit(state.copyWith(phase: OrganizationPhase.saving, clearError: true));
    try {
      await _gateway.save(draft);
      final snapshot = await _gateway.load(_context);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        snapshot: snapshot,
        clearDraft: true,
      ));
      return true;
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        error: error.toString(),
      ));
      return false;
    }
  }

  List<String> _missingRequired(OrganizationDraft draft) {
    if (draft.step != 0) return const [];
    final fields = switch (draft.kind) {
      OrganizationUnitKind.holding => const {
          'holding_name': 'نام هلدینگ',
          'holding_code': 'کد هلدینگ',
        },
      OrganizationUnitKind.company => const {
          'company_name': 'نام شرکت یا دفتر',
          'abbr': 'کد اختصاری',
        },
      OrganizationUnitKind.branch => const {
          'company': 'شرکت مادر',
          'branch_name': 'نام شعبه',
          'branch_code': 'کد شعبه',
        },
    };
    return [
      for (final entry in fields.entries)
        if ((draft.values[entry.key] ?? '').trim().isEmpty) entry.value,
    ];
  }
}
