import 'package:asoud_pwa/features/organization_settings/domain/organization_gateway.dart';
import 'package:asoud_pwa/features/organization_settings/domain/organization_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum OrganizationPhase { initial, loading, ready, saving, failure }

enum SettingsView { dashboard, structure, financial }

enum FinancialSection {
  general,
  defaultAccounts,
  chartOfAccounts,
  floatingDetails,
}

class OrganizationSettingsState extends Equatable {
  const OrganizationSettingsState({
    this.phase = OrganizationPhase.initial,
    this.view = SettingsView.dashboard,
    this.snapshot = const OrganizationSnapshot(),
    this.financial,
    this.financialDraft,
    this.accountRules,
    this.accountDraft,
    this.detailManagement,
    this.detailGroupDraft,
    this.floatingDetailDraft,
    this.fiscalYearDraft,
    this.fiscalPeriodDraft,
    this.periodLockDraft,
    this.periodUnlockDraft,
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
  final FloatingDetailManagementSnapshot? detailManagement;
  final FloatingDetailGroupDraft? detailGroupDraft;
  final FloatingDetailDraft? floatingDetailDraft;
  final FiscalYearDraft? fiscalYearDraft;
  final FiscalPeriodDraft? fiscalPeriodDraft;
  final PeriodLockDraft? periodLockDraft;
  final PeriodUnlockDraft? periodUnlockDraft;
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
    FloatingDetailManagementSnapshot? detailManagement,
    FloatingDetailGroupDraft? detailGroupDraft,
    FloatingDetailDraft? floatingDetailDraft,
    FiscalYearDraft? fiscalYearDraft,
    FiscalPeriodDraft? fiscalPeriodDraft,
    PeriodLockDraft? periodLockDraft,
    PeriodUnlockDraft? periodUnlockDraft,
    FinancialSection? financialSection,
    OrganizationDraft? draft,
    String? error,
    bool clearDraft = false,
    bool clearAccountDraft = false,
    bool clearDetailGroupDraft = false,
    bool clearFloatingDetailDraft = false,
    bool clearFiscalYearDraft = false,
    bool clearFiscalPeriodDraft = false,
    bool clearPeriodLockDraft = false,
    bool clearPeriodUnlockDraft = false,
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
        detailManagement: detailManagement ?? this.detailManagement,
        detailGroupDraft: clearDetailGroupDraft
            ? null
            : detailGroupDraft ?? this.detailGroupDraft,
        floatingDetailDraft: clearFloatingDetailDraft
            ? null
            : floatingDetailDraft ?? this.floatingDetailDraft,
        fiscalYearDraft: clearFiscalYearDraft
            ? null
            : fiscalYearDraft ?? this.fiscalYearDraft,
        fiscalPeriodDraft: clearFiscalPeriodDraft
            ? null
            : fiscalPeriodDraft ?? this.fiscalPeriodDraft,
        periodLockDraft: clearPeriodLockDraft
            ? null
            : periodLockDraft ?? this.periodLockDraft,
        periodUnlockDraft: clearPeriodUnlockDraft
            ? null
            : periodUnlockDraft ?? this.periodUnlockDraft,
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
        detailManagement,
        detailGroupDraft,
        floatingDetailDraft,
        fiscalYearDraft,
        fiscalPeriodDraft,
        periodLockDraft,
        periodUnlockDraft,
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
      final detailManagement = state.view == SettingsView.financial
          ? await _gateway.loadFloatingDetails(_context)
          : state.detailManagement;
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        snapshot: snapshot,
        financial: financial,
        financialDraft: financial?.toDraft(),
        accountRules: accountRules,
        detailManagement: detailManagement,
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
      final detailManagement = await _gateway.loadFloatingDetails(_context);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        financial: financial,
        financialDraft: financial.toDraft(),
        accountRules: accountRules,
        detailManagement: detailManagement,
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
    if (section == FinancialSection.general ||
        section == FinancialSection.defaultAccounts ||
        (section == FinancialSection.floatingDetails &&
            state.detailManagement != null) ||
        (section != FinancialSection.floatingDetails &&
            state.accountRules != null)) {
      return;
    }
    emit(state.copyWith(phase: OrganizationPhase.loading));
    try {
      if (section == FinancialSection.floatingDetails) {
        final snapshot = await _gateway.loadFloatingDetails(_context);
        emit(state.copyWith(
          phase: OrganizationPhase.ready,
          detailManagement: snapshot,
        ));
      } else {
        final snapshot = await _gateway.loadAccountRules(_context);
        emit(state.copyWith(
          phase: OrganizationPhase.ready,
          accountRules: snapshot,
        ));
      }
    } on Object catch (error) {
      emit(state.copyWith(
        phase: OrganizationPhase.failure,
        error: error.toString(),
      ));
    }
  }

  void startDetailGroup([FloatingDetailGroup? group]) => emit(state.copyWith(
        detailGroupDraft: group == null
            ? const FloatingDetailGroupDraft()
            : FloatingDetailGroupDraft.fromGroup(group),
        clearError: true,
      ));

  void updateDetailGroup({
    String? title,
    String? code,
    String? detailType,
    String? parentGroup,
    bool? enabled,
  }) {
    final draft = state.detailGroupDraft;
    if (draft == null) return;
    emit(state.copyWith(
      detailGroupDraft: draft.copyWith(
        title: title,
        code: code,
        detailType: detailType,
        parentGroup: parentGroup,
        enabled: enabled,
      ),
      clearError: true,
    ));
  }

  void cancelDetailGroup() =>
      emit(state.copyWith(clearDetailGroupDraft: true, clearError: true));

  Future<bool> saveDetailGroup() async {
    final draft = state.detailGroupDraft;
    if (draft == null) return false;
    if (draft.title.trim().isEmpty || draft.code.trim().isEmpty) {
      emit(state.copyWith(error: 'عنوان و کد گروه تفصیلی الزامی است.'));
      return false;
    }
    emit(state.copyWith(phase: OrganizationPhase.saving, clearError: true));
    try {
      final snapshot = await _gateway.saveFloatingDetailGroup(_context, draft);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        detailManagement: snapshot,
        clearDetailGroupDraft: true,
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

  void startFloatingDetail([FloatingDetailRecord? detail]) =>
      emit(state.copyWith(
        floatingDetailDraft: detail == null
            ? const FloatingDetailDraft()
            : FloatingDetailDraft.fromDetail(detail),
        clearError: true,
      ));

  void updateFloatingDetail({
    String? title,
    String? group,
    String? code,
    String? referenceDoctype,
    String? referenceName,
    bool? enabled,
    bool? companyEnabled,
  }) {
    final draft = state.floatingDetailDraft;
    if (draft == null) return;
    emit(state.copyWith(
      floatingDetailDraft: draft.copyWith(
        title: title,
        group: group,
        code: code,
        referenceDoctype: referenceDoctype,
        referenceName: referenceName,
        enabled: enabled,
        companyEnabled: companyEnabled,
      ),
      clearError: true,
    ));
  }

  void cancelFloatingDetail() =>
      emit(state.copyWith(clearFloatingDetailDraft: true, clearError: true));

  Future<bool> saveFloatingDetail() async {
    final draft = state.floatingDetailDraft;
    if (draft == null) return false;
    if (draft.title.trim().isEmpty ||
        draft.group.trim().isEmpty ||
        draft.code.trim().isEmpty) {
      emit(state.copyWith(error: 'عنوان، گروه و کد تفصیلی الزامی است.'));
      return false;
    }
    emit(state.copyWith(phase: OrganizationPhase.saving, clearError: true));
    try {
      final snapshot = await _gateway.saveFloatingDetail(_context, draft);
      final accountRules = await _gateway.loadAccountRules(_context);
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        detailManagement: snapshot,
        accountRules: accountRules,
        clearFloatingDetailDraft: true,
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

  void startChildAccount(ChartAccount parent) {
    if (!parent.isGroup) {
      emit(state.copyWith(
        error: 'حساب معین سندپذیر است و نمی‌تواند زیرحساب داشته باشد.',
      ));
      return;
    }
    final accountLevel =
        parent.accountLevel == 'Group' ? 'Ledger' : 'Subsidiary';
    emit(state.copyWith(
      accountDraft: ChartAccountDraft(
        parentAccount: parent.name,
        accountLevel: accountLevel,
        isGroup: accountLevel != 'Subsidiary',
      ),
      clearError: true,
    ));
  }

  void startSiblingAccount(ChartAccount account) {
    emit(state.copyWith(
      accountDraft: ChartAccountDraft(
        parentAccount: account.parentAccount,
        accountLevel: account.accountLevel,
        isGroup: account.accountLevel != 'Subsidiary',
      ),
      clearError: true,
    ));
  }

  void cancelAccount() =>
      emit(state.copyWith(clearAccountDraft: true, clearError: true));

  void updateAccount({
    String? accountName,
    String? accountNumber,
    String? accountLevel,
    String? parentAccount,
    String? accountType,
    bool? disabled,
  }) {
    final draft = state.accountDraft;
    if (draft == null) return;
    final nextLevel = accountLevel ?? draft.accountLevel;
    final nextIsGroup = nextLevel != 'Subsidiary';
    emit(state.copyWith(
      accountDraft: draft.copyWith(
        accountName: accountName,
        accountNumber: accountNumber,
        accountLevel: nextLevel,
        parentAccount: parentAccount,
        accountType: accountType,
        isGroup: nextIsGroup,
        disabled: disabled,
        rules: nextIsGroup ? const [] : null,
      ),
      clearError: true,
    ));
  }

  void toggleAccountDetailGroup(FloatingDetailGroup group, bool selected) {
    final draft = state.accountDraft;
    if (draft == null || draft.isGroup) return;
    final rows = [...draft.rules]
      ..removeWhere((rule) => rule.detailGroup == group.name);
    if (selected) {
      rows.add(AccountDetailRuleDraft(
        detailType: group.detailType,
        detailGroup: group.name,
      ));
    }
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
      if (draft.accountLevel.trim().isEmpty) 'سطح حساب',
      if (draft.parentAccount.trim().isEmpty) 'حساب والد',
    ];
    if (missing.isNotEmpty) {
      emit(state.copyWith(
          error: 'فیلدهای الزامی را تکمیل کنید: ${missing.join('، ')}'));
      return false;
    }
    if (draft.accountLevel != 'Subsidiary' && draft.rules.isNotEmpty) {
      emit(state.copyWith(
          error: 'برای حساب گروه یا کل نمی‌توان قاعده تفصیلی تعریف کرد.'));
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
    String? defaultReceivableAccount,
    String? defaultPayableAccount,
    String? defaultIncomeAccount,
    String? defaultExpenseAccount,
    String? defaultCashAccount,
    String? defaultBankAccount,
    String? stockAdjustmentAccount,
  }) {
    final draft = state.financialDraft;
    if (draft == null) return;
    emit(state.copyWith(
      financialDraft: draft.copyWith(
        coaTemplate: coaTemplate,
        amountInputUnit: amountInputUnit,
        calendarDisplay: calendarDisplay,
        defaultReceivableAccount: defaultReceivableAccount,
        defaultPayableAccount: defaultPayableAccount,
        defaultIncomeAccount: defaultIncomeAccount,
        defaultExpenseAccount: defaultExpenseAccount,
        defaultCashAccount: defaultCashAccount,
        defaultBankAccount: defaultBankAccount,
        stockAdjustmentAccount: stockAdjustmentAccount,
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

  void startFiscalYear([Map<String, dynamic>? row]) => emit(state.copyWith(
        fiscalYearDraft: row == null
            ? const FiscalYearDraft()
            : FiscalYearDraft.fromJson(row),
        clearError: true,
      ));

  void updateFiscalYear({
    String? yearName,
    String? fromDate,
    String? toDate,
    bool? disabled,
  }) {
    final draft = state.fiscalYearDraft;
    if (draft == null) return;
    emit(state.copyWith(
      fiscalYearDraft: draft.copyWith(
        yearName: yearName,
        fromDate: fromDate,
        toDate: toDate,
        disabled: disabled,
      ),
      clearError: true,
    ));
  }

  void cancelFiscalYear() =>
      emit(state.copyWith(clearFiscalYearDraft: true, clearError: true));

  Future<bool> saveFiscalYear() async {
    final draft = state.fiscalYearDraft;
    if (draft == null) return false;
    if (draft.yearName.trim().isEmpty ||
        draft.fromDate.trim().isEmpty ||
        draft.toDate.trim().isEmpty) {
      emit(state.copyWith(error: 'نام سال مالی و بازه تاریخ الزامی است.'));
      return false;
    }
    return _saveFinancialChild(
      () => _gateway.saveFiscalYear(_context, draft),
      clearFiscalYearDraft: true,
    );
  }

  void startFiscalPeriod([Map<String, dynamic>? row]) {
    final years = state.financial?.fiscalYears ?? const [];
    emit(state.copyWith(
      fiscalPeriodDraft: row == null
          ? FiscalPeriodDraft(
              fiscalYear:
                  years.isEmpty ? '' : years.first['name']?.toString() ?? '',
            )
          : FiscalPeriodDraft.fromJson(row),
      clearError: true,
    ));
  }

  void updateFiscalPeriod({
    String? fiscalYear,
    String? periodName,
    String? periodType,
    String? fromDate,
    String? toDate,
    bool? enabled,
  }) {
    final draft = state.fiscalPeriodDraft;
    if (draft == null) return;
    emit(state.copyWith(
      fiscalPeriodDraft: draft.copyWith(
        fiscalYear: fiscalYear,
        periodName: periodName,
        periodType: periodType,
        fromDate: fromDate,
        toDate: toDate,
        enabled: enabled,
      ),
      clearError: true,
    ));
  }

  void cancelFiscalPeriod() =>
      emit(state.copyWith(clearFiscalPeriodDraft: true, clearError: true));

  Future<bool> saveFiscalPeriod() async {
    final draft = state.fiscalPeriodDraft;
    if (draft == null) return false;
    if (draft.fiscalYear.trim().isEmpty ||
        draft.periodName.trim().isEmpty ||
        draft.fromDate.trim().isEmpty ||
        draft.toDate.trim().isEmpty) {
      emit(
          state.copyWith(error: 'سال مالی، نام دوره و بازه تاریخ الزامی است.'));
      return false;
    }
    return _saveFinancialChild(
      () => _gateway.saveFiscalPeriod(_context, draft),
      clearFiscalPeriodDraft: true,
    );
  }

  void startPeriodLock([Map<String, dynamic>? period]) {
    final years = state.financial?.fiscalYears ?? const [];
    emit(state.copyWith(
      periodLockDraft: PeriodLockDraft(
        fiscalYear: period?['fiscal_year']?.toString() ??
            (years.isEmpty ? '' : years.first['name']?.toString() ?? ''),
        fiscalPeriod: period?['name']?.toString() ?? '',
        fromDate: period?['from_date']?.toString() ?? '',
        toDate: period?['to_date']?.toString() ?? '',
      ),
      clearError: true,
    ));
  }

  void updatePeriodLock({
    String? fiscalYear,
    String? fiscalPeriod,
    String? fromDate,
    String? toDate,
    String? reason,
  }) {
    final draft = state.periodLockDraft;
    if (draft == null) return;
    var next = draft.copyWith(
      fiscalYear: fiscalYear,
      fiscalPeriod: fiscalPeriod,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
    );
    if (fiscalPeriod != null && fiscalPeriod.isNotEmpty) {
      final rows = state.financial?.fiscalPeriods ?? const [];
      final matches =
          rows.where((row) => row['name']?.toString() == fiscalPeriod);
      if (matches.isNotEmpty) {
        final row = matches.first;
        next = next.copyWith(
          fiscalYear: row['fiscal_year']?.toString() ?? '',
          fromDate: row['from_date']?.toString() ?? '',
          toDate: row['to_date']?.toString() ?? '',
        );
      }
    }
    emit(state.copyWith(periodLockDraft: next, clearError: true));
  }

  void cancelPeriodLock() =>
      emit(state.copyWith(clearPeriodLockDraft: true, clearError: true));

  Future<bool> savePeriodLock() async {
    final draft = state.periodLockDraft;
    if (draft == null) return false;
    if (draft.fiscalYear.trim().isEmpty ||
        draft.fromDate.trim().isEmpty ||
        draft.toDate.trim().isEmpty ||
        draft.reason.trim().isEmpty) {
      emit(state.copyWith(error: 'سال مالی، بازه و دلیل قفل الزامی است.'));
      return false;
    }
    return _saveFinancialChild(
      () => _gateway.lockFinancialPeriod(_context, draft),
      clearPeriodLockDraft: true,
    );
  }

  void startPeriodUnlock(String lockName) => emit(state.copyWith(
        periodUnlockDraft: PeriodUnlockDraft(lockName: lockName),
        clearError: true,
      ));

  void updatePeriodUnlock(String reason) {
    final draft = state.periodUnlockDraft;
    if (draft == null) return;
    emit(state.copyWith(
      periodUnlockDraft: draft.copyWith(reason: reason),
      clearError: true,
    ));
  }

  void cancelPeriodUnlock() =>
      emit(state.copyWith(clearPeriodUnlockDraft: true, clearError: true));

  Future<bool> savePeriodUnlock() async {
    final draft = state.periodUnlockDraft;
    if (draft == null) return false;
    if (draft.reason.trim().isEmpty) {
      emit(state.copyWith(error: 'دلیل بازگشایی الزامی است.'));
      return false;
    }
    return _saveFinancialChild(
      () => _gateway.unlockFinancialPeriod(
        _context,
        draft.lockName,
        draft.reason,
      ),
      clearPeriodUnlockDraft: true,
    );
  }

  Future<bool> _saveFinancialChild(
    Future<FinancialSettingsSnapshot> Function() action, {
    bool clearFiscalYearDraft = false,
    bool clearFiscalPeriodDraft = false,
    bool clearPeriodLockDraft = false,
    bool clearPeriodUnlockDraft = false,
  }) async {
    emit(state.copyWith(phase: OrganizationPhase.saving, clearError: true));
    try {
      final financial = await action();
      emit(state.copyWith(
        phase: OrganizationPhase.ready,
        financial: financial,
        financialDraft: financial.toDraft(),
        clearFiscalYearDraft: clearFiscalYearDraft,
        clearFiscalPeriodDraft: clearFiscalPeriodDraft,
        clearPeriodLockDraft: clearPeriodLockDraft,
        clearPeriodUnlockDraft: clearPeriodUnlockDraft,
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
