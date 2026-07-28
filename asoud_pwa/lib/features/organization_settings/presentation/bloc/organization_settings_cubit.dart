import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum OrganizationPhase { initial, loading, ready, saving, failure }

enum SettingsView { dashboard, structure, financial }

enum FinancialSection { general, chartOfAccounts, dimensions }

class OrganizationSettingsState extends Equatable {
  const OrganizationSettingsState({
    this.phase = OrganizationPhase.initial,
    this.view = SettingsView.dashboard,
    this.snapshot = const OrganizationSnapshot(),
    this.financial,
    this.financialDraft,
    this.accountRules,
    this.accountDraft,
    this.financialSection = FinancialSection.general,
    this.draft,
    this.error,
  });

  final OrganizationPhase phase;
  final SettingsView view;
  final OrganizationSnapshot snapshot;
  final FinancialSettingsSnapshot? financial;
  final FinancialSettingsDraft? financialDraft;
  final AccountRulesSnapshot? accountRules;
  final ChartAccountDraft? accountDraft;
  final FinancialSection financialSection;
  final OrganizationDraft? draft;
  final String? error;

  OrganizationSettingsState copyWith({
    OrganizationPhase? phase,
    SettingsView? view,
    OrganizationSnapshot? snapshot,
    FinancialSettingsSnapshot? financial,
    FinancialSettingsDraft? financialDraft,
    AccountRulesSnapshot? accountRules,
    ChartAccountDraft? accountDraft,
    FinancialSection? financialSection,
    OrganizationDraft? draft,
    String? error,
    bool clearDraft = false,
    bool clearAccountDraft = false,
    bool clearError = false,
  }) =>
      OrganizationSettingsState(
        phase: phase ?? this.phase,
        view: view ?? this.view,
        snapshot: snapshot ?? this.snapshot,
        financial: financial ?? this.financial,
        financialDraft: financialDraft ?? this.financialDraft,
        accountRules: accountRules ?? this.accountRules,
        accountDraft:
            clearAccountDraft ? null : accountDraft ?? this.accountDraft,
        financialSection: financialSection ?? this.financialSection,
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
        accountRules,
        accountDraft,
        financialSection,
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
      final accountRules = state.view == SettingsView.financial
          ? await _gateway.loadAccountRules(_context)
          : state.accountRules;
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        snapshot: snapshot,
        financial: financial,
        financialDraft: financial?.toDraft(),
        accountRules: accountRules,
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
      final accountRules = await _gateway.loadAccountRules(_context);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        financial: financial,
        financialDraft: financial.toDraft(),
        accountRules: accountRules,
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.failure,
        error: error.toString(),
      ));
    }
  }

  Future<void> showFinancialSection(FinancialSection section) async {
    emit(state.copyWith(financialSection: section, clearError: true));
    if (section == FinancialSection.general || state.accountRules != null) {
      return;
    }
    emit(state.copyWith(phase: OrganizationPhase.loading));
    try {
      final snapshot = await _gateway.loadAccountRules(_context);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        accountRules: snapshot,
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.failure,
        error: error.toString(),
      ));
    }
  }

  void startAccount([ChartAccount? account]) {
    final snapshot = state.accountRules;
    if (snapshot == null) return;
    emit(state.copyWith(
      accountDraft: account == null
          ? const ChartAccountDraft()
          : ChartAccountDraft.fromAccount(
              account,
              snapshot.rules[account.name] ?? const [],
            ),
      clearError: true,
    ));
  }

  void cancelAccount() =>
      emit(state.copyWith(clearAccountDraft: true, clearError: true));

  void updateAccount({
    String? accountName,
    String? accountNumber,
    String? parentAccount,
    String? accountType,
    bool? isGroup,
    bool? disabled,
  }) {
    final draft = state.accountDraft;
    if (draft == null) return;
    emit(state.copyWith(
      accountDraft: draft.copyWith(
        accountName: accountName,
        accountNumber: accountNumber,
        parentAccount: parentAccount,
        accountType: accountType,
        isGroup: isGroup,
        disabled: disabled,
        rules: isGroup == true ? const [] : null,
      ),
      clearError: true,
    ));
  }

  void addDetailRule(String detailType) {
    final draft = state.accountDraft;
    if (draft == null ||
        detailType.isEmpty ||
        draft.rules.any((rule) => rule.detailType == detailType)) {
      return;
    }
    emit(state.copyWith(
      accountDraft: draft.copyWith(
        rules: [
          ...draft.rules,
          AccountDetailRuleDraft(detailType: detailType),
        ],
      ),
      clearError: true,
    ));
  }

  void updateDetailRule(
    int index, {
    bool? required,
    bool? enabled,
    String? defaultFloatingDetail,
    String? validFrom,
    String? validTo,
  }) {
    final draft = state.accountDraft;
    if (draft == null || index < 0 || index >= draft.rules.length) return;
    final rows = [...draft.rules];
    if (required == true) {
      for (var i = 0; i < rows.length; i++) {
        rows[i] = rows[i].copyWith(required: i == index);
      }
    }
    rows[index] = rows[index].copyWith(
      required: required,
      enabled: enabled,
      defaultFloatingDetail: defaultFloatingDetail,
      validFrom: validFrom,
      validTo: validTo,
    );
    emit(state.copyWith(
      accountDraft: draft.copyWith(rules: rows),
      clearError: true,
    ));
  }

  void removeDetailRule(int index) {
    final draft = state.accountDraft;
    if (draft == null || index < 0 || index >= draft.rules.length) return;
    final rows = [...draft.rules]..removeAt(index);
    emit(state.copyWith(
      accountDraft: draft.copyWith(rules: rows),
      clearError: true,
    ));
  }

  Future<bool> saveChartAccount() async {
    final draft = state.accountDraft;
    if (draft == null) return false;
    final missing = <String>[
      if (draft.accountName.trim().isEmpty) 'عنوان حساب',
      if (draft.accountNumber.trim().isEmpty) 'کد حساب',
      if (draft.parentAccount.trim().isEmpty) 'حساب والد',
    ];
    if (missing.isNotEmpty) {
      emit(state.copyWith(
          error: 'فیلدهای الزامی را تکمیل کنید: ${missing.join('، ')}'));
      return false;
    }
    if (draft.isGroup && draft.rules.isNotEmpty) {
      emit(state.copyWith(
          error: 'برای حساب گروه نمی‌توان قاعده تفصیلی تعریف کرد.'));
      return false;
    }
    emit(state.copyWith(phase: OrganizationPhase.saving, clearError: true));
    try {
      final snapshot = await _gateway.saveChartAccount(_context, draft);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        accountRules: snapshot,
        clearAccountDraft: true,
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
