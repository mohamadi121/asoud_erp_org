import 'package:asoud_pwa/features/iran_accounting/domain/accounting_settings.dart';
import 'package:asoud_pwa/features/iran_accounting/domain/iran_accounting_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum IranAccountingSection { dashboard, numbering }

enum IranAccountingPhase { initial, loading, ready, saving, failure }

class IranAccountingState extends Equatable {
  const IranAccountingState({
    this.phase = IranAccountingPhase.initial,
    this.section = IranAccountingSection.dashboard,
    this.settings,
    this.chart = const [],
    this.numbering = const {},
    this.closingRuns = const [],
    this.numberingWorkspace = const NumberingWorkspace(),
    this.selectedDocuments = const {},
    this.amountResult,
    this.dateResult,
    this.balanceRows,
    this.message,
    this.error,
  });

  final IranAccountingPhase phase;
  final IranAccountingSection section;
  final AccountingSettings? settings;
  final List<AccountSummary> chart;
  final Map<String, dynamic> numbering;
  final List<Map<String, dynamic>> closingRuns;
  final NumberingWorkspace numberingWorkspace;
  final Set<String> selectedDocuments;
  final String? amountResult;
  final String? dateResult;
  final List<TrialBalanceRow>? balanceRows;
  final String? message;
  final String? error;

  IranAccountingState copyWith({
    IranAccountingPhase? phase,
    IranAccountingSection? section,
    AccountingSettings? settings,
    List<AccountSummary>? chart,
    Map<String, dynamic>? numbering,
    List<Map<String, dynamic>>? closingRuns,
    NumberingWorkspace? numberingWorkspace,
    Set<String>? selectedDocuments,
    String? amountResult,
    String? dateResult,
    List<TrialBalanceRow>? balanceRows,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) =>
      IranAccountingState(
        phase: phase ?? this.phase,
        section: section ?? this.section,
        settings: settings ?? this.settings,
        chart: chart ?? this.chart,
        numbering: numbering ?? this.numbering,
        closingRuns: closingRuns ?? this.closingRuns,
        numberingWorkspace: numberingWorkspace ?? this.numberingWorkspace,
        selectedDocuments: selectedDocuments ?? this.selectedDocuments,
        amountResult: amountResult ?? this.amountResult,
        dateResult: dateResult ?? this.dateResult,
        balanceRows: balanceRows ?? this.balanceRows,
        message: clearMessage ? null : message ?? this.message,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [
        phase,
        section,
        settings,
        chart,
        numbering,
        closingRuns,
        numberingWorkspace,
        selectedDocuments,
        amountResult,
        dateResult,
        balanceRows,
        message,
        error,
      ];
}

class IranAccountingCubit extends Cubit<IranAccountingState> {
  IranAccountingCubit(
    this._gateway,
    this._context, {
    IranAccountingSection initialSection = IranAccountingSection.dashboard,
  }) : super(IranAccountingState(section: initialSection));

  final IranAccountingGateway _gateway;
  final WorkContext _context;

  Future<void> load() async {
    emit(state.copyWith(
      phase: IranAccountingPhase.loading,
      clearError: true,
      clearMessage: true,
    ));
    try {
      final settings = await _gateway.loadSettings(_context.company);
      final chart = await _gateway.loadChartOfAccounts(_context.company);
      final numbering = await _gateway.loadNumberingOverview(_context.company);
      final closingRuns = await _gateway.loadClosingRuns(_context.company);
      final workspace = await _gateway.loadNumberingWorkspace(_context.company);
      emit(state.copyWith(
        phase: IranAccountingPhase.ready,
        settings: settings,
        chart: chart,
        numbering: numbering,
        closingRuns: closingRuns,
        numberingWorkspace: workspace,
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: IranAccountingPhase.failure,
        error: error.toString(),
      ));
    }
  }

  void showSection(IranAccountingSection section) => emit(state.copyWith(
        section: section,
        clearError: true,
        clearMessage: true,
      ));

  Future<void> filterCandidates(String? postingDate) async => _run(() async {
        final workspace = await _gateway.loadNumberingWorkspace(
          _context.company,
          postingDate: postingDate,
        );
        emit(state.copyWith(
          phase: IranAccountingPhase.ready,
          numberingWorkspace: workspace,
          selectedDocuments: const {},
        ));
      });

  void toggleDocument(String name, bool selected) {
    final values = {...state.selectedDocuments};
    selected ? values.add(name) : values.remove(name);
    emit(state.copyWith(selectedDocuments: values, clearError: true));
  }

  Future<void> consolidateSelected(String reason) async {
    final workspace = state.numberingWorkspace;
    final dates = workspace.candidates
        .where((row) => state.selectedDocuments.contains(row.name))
        .map((row) => row.postingDate)
        .toSet();
    if (state.selectedDocuments.length < 2 || dates.length != 1) {
      emit(state.copyWith(
        error: 'حداقل دو سند از یک روز را انتخاب کنید.',
        clearMessage: true,
      ));
      return;
    }
    if (reason.trim().isEmpty) {
      emit(state.copyWith(
        error: 'دلیل ادغام الزامی است.',
        clearMessage: true,
      ));
      return;
    }
    await _run(() async {
      final name = await _gateway.consolidateDocuments(
        company: _context.company,
        postingDate: dates.single,
        documents: state.selectedDocuments.toList(growable: false),
        reason: reason.trim(),
      );
      final refreshed = await _gateway.loadNumberingWorkspace(
        _context.company,
        postingDate:
            workspace.postingDate.isEmpty ? null : workspace.postingDate,
      );
      emit(state.copyWith(
        phase: IranAccountingPhase.ready,
        numberingWorkspace: refreshed,
        selectedDocuments: const {},
        message: 'ادغام روزانه ثبت شد: $name',
        clearError: true,
      ));
    });
  }

  Future<void> finalizeNumbering({
    required String fiscalYear,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    if ([fiscalYear, fromDate, toDate, reason]
        .any((value) => value.trim().isEmpty)) {
      emit(state.copyWith(
        error: 'تمام فیلدهای عملیات شماره‌گذاری الزامی هستند.',
        clearMessage: true,
      ));
      return;
    }
    await _run(() async {
      final batch = await _gateway.finalizeNumbering(
        company: _context.company,
        fiscalYear: fiscalYear.trim(),
        fromDate: fromDate.trim(),
        toDate: toDate.trim(),
        reason: reason.trim(),
      );
      final numbering = await _gateway.loadNumberingOverview(_context.company);
      final workspace = await _gateway.loadNumberingWorkspace(_context.company);
      emit(state.copyWith(
        phase: IranAccountingPhase.ready,
        numbering: numbering,
        numberingWorkspace: workspace,
        selectedDocuments: const {},
        message: 'شماره‌گذاری قطعی ثبت شد: $batch',
        clearError: true,
      ));
    });
  }

  Future<void> applySetup() async => _run(() async {
        final settings = await _gateway.applySetup(_context.company);
        emit(state.copyWith(
          phase: IranAccountingPhase.ready,
          settings: settings,
          message: 'راه‌اندازی حسابداری ایران تکمیل شد.',
          clearError: true,
        ));
      });

  Future<void> convertAmount({
    required String value,
    required String inputUnit,
  }) async =>
      _run(() async {
        final result = await _gateway.convertAmount(
          value: value,
          inputUnit: inputUnit,
          outputUnit: inputUnit == 'IRR' ? 'TOMAN' : 'IRR',
        );
        emit(state.copyWith(
          phase: IranAccountingPhase.ready,
          amountResult: result,
          clearError: true,
        ));
      });

  Future<void> convertDate(String value) async => _run(() async {
        final result = await _gateway.fromJalali(value);
        emit(state.copyWith(
          phase: IranAccountingPhase.ready,
          dateResult: result,
          clearError: true,
        ));
      });

  Future<void> loadTrialBalance(String fromDate, String toDate) async =>
      _run(() async {
        final rows = await _gateway.loadTrialBalance(
          company: _context.company,
          fromDate: fromDate,
          toDate: toDate,
        );
        emit(state.copyWith(
          phase: IranAccountingPhase.ready,
          balanceRows: rows,
          clearError: true,
        ));
      });

  Future<void> _run(Future<void> Function() callback) async {
    emit(state.copyWith(
      phase: IranAccountingPhase.saving,
      clearError: true,
      clearMessage: true,
    ));
    try {
      await callback();
    } on Object catch (error) {
      emit(state.copyWith(
        phase: IranAccountingPhase.failure,
        error: error.toString(),
      ));
    }
  }
}
