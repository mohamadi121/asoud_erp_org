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
    this.financial,
    this.financialDraft,
    this.draft,
    this.error,
  });

  final OrganizationPhase phase;
  final SettingsView view;
  final OrganizationSnapshot snapshot;
  final FinancialSettingsSnapshot? financial;
  final FinancialSettingsDraft? financialDraft;
  final OrganizationDraft? draft;
  final String? error;

  OrganizationSettingsState copyWith({
    OrganizationPhase? phase,
    SettingsView? view,
    OrganizationSnapshot? snapshot,
    FinancialSettingsSnapshot? financial,
    FinancialSettingsDraft? financialDraft,
    OrganizationDraft? draft,
    String? error,
    bool clearDraft = false,
    bool clearError = false,
  }) =>
      OrganizationSettingsState(
        phase: phase ?? this.phase,
        view: view ?? this.view,
        snapshot: snapshot ?? this.snapshot,
        financial: financial ?? this.financial,
        financialDraft: financialDraft ?? this.financialDraft,
        draft: clearDraft ? null : draft ?? this.draft,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [
        phase,
        view,
        snapshot,
        financial,
        financialDraft,
        draft,
        error,
      ];
}

class OrganizationSettingsCubit extends Cubit<OrganizationSettingsState> {
  OrganizationSettingsCubit(
    this._gateway,
    this._context, {
    SettingsView initialView = SettingsView.dashboard,
  }) : super(OrganizationSettingsState(view: initialView));

  final OrganizationGateway _gateway;
  final WorkContext _context;

  Future<void> load() async {
    emit(state.copyWith(phase: OrganizationPhase.loading, clearError: true));
    try {
      final snapshot = await _gateway.load(_context);
      final financial = state.view == SettingsView.financial
          ? await _gateway.loadFinancial(_context)
          : state.financial;
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        snapshot: snapshot,
        financial: financial,
        financialDraft: financial?.toDraft(),
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.failure,
        error: error.toString(),
      ));
    }
  }

  Future<void> show(SettingsView view) async {
    emit(state.copyWith(view: view, clearError: true));
    if (view != SettingsView.financial || state.financial != null) return;
    emit(state.copyWith(phase: OrganizationPhase.loading));
    try {
      final financial = await _gateway.loadFinancial(_context);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        financial: financial,
        financialDraft: financial.toDraft(),
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.failure,
        error: error.toString(),
      ));
    }
  }

  void updateFinancial({
    String? coaTemplate,
    String? amountInputUnit,
    String? calendarDisplay,
  }) {
    final draft = state.financialDraft;
    if (draft == null) return;
    emit(state.copyWith(
      financialDraft: draft.copyWith(
        coaTemplate: coaTemplate,
        amountInputUnit: amountInputUnit,
        calendarDisplay: calendarDisplay,
      ),
      clearError: true,
    ));
  }

  Future<bool> saveFinancial() async {
    final draft = state.financialDraft;
    if (draft == null) return false;
    if (draft.coaTemplate.trim().isEmpty) {
      emit(state.copyWith(error: 'الگوی نمودار حساب‌ها را انتخاب کنید.'));
      return false;
    }
    emit(state.copyWith(phase: OrganizationPhase.saving, clearError: true));
    try {
      final financial = await _gateway.saveFinancial(_context, draft);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        financial: financial,
        financialDraft: financial.toDraft(),
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
