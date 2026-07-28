import 'package:asoud_pwa/features/session/domain/session_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SessionPhase { signedOut, loading, selectingContext, ready, failure }

class SessionState extends Equatable {
  const SessionState({
    this.phase = SessionPhase.signedOut,
    this.contexts = const [],
    this.selected,
    this.error,
  });

  final SessionPhase phase;
  final List<WorkContext> contexts;
  final WorkContext? selected;
  final String? error;

  SessionState copyWith({
    SessionPhase? phase,
    List<WorkContext>? contexts,
    WorkContext? selected,
    String? error,
    bool clearError = false,
  }) =>
      SessionState(
        phase: phase ?? this.phase,
        contexts: contexts ?? this.contexts,
        selected: selected ?? this.selected,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [phase, contexts, selected, error];
}

class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._gateway) : super(const SessionState());

  final SessionGateway _gateway;

  Future<void> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      emit(
        state.copyWith(
          phase: SessionPhase.failure,
          error:
              '\u0646\u0627\u0645 \u06a9\u0627\u0631\u0628\u0631\u06cc \u0648 \u0631\u0645\u0632 \u0639\u0628\u0648\u0631 \u0627\u0644\u0632\u0627\u0645\u06cc \u0627\u0633\u062a.',
        ),
      );
      return;
    }
    emit(state.copyWith(phase: SessionPhase.loading, clearError: true));
    try {
      final contexts =
          await _gateway.login(username: username.trim(), password: password);
      emit(
        SessionState(
          phase: SessionPhase.selectingContext,
          contexts: contexts,
          selected: contexts.length == 1 ? contexts.single : null,
        ),
      );
    } on Object catch (error) {
      emit(SessionState(phase: SessionPhase.failure, error: error.toString()));
    }
  }

  void selectContext(WorkContext? context) =>
      emit(state.copyWith(selected: context, clearError: true));

  Future<void> continueToWorkspace() async {
    final selected = state.selected;
    if (selected == null) return;
    emit(state.copyWith(phase: SessionPhase.loading, clearError: true));
    try {
      await _gateway.activateContext(selected);
      emit(state.copyWith(phase: SessionPhase.ready, clearError: true));
    } on Object catch (error) {
      emit(
        state.copyWith(
          phase: SessionPhase.selectingContext,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> switchContext(WorkContext context) async {
    if (context == state.selected) return;
    final previous = state.selected;
    emit(state.copyWith(
      phase: SessionPhase.loading,
      selected: context,
      clearError: true,
    ));
    try {
      await _gateway.activateContext(context);
      emit(state.copyWith(phase: SessionPhase.ready, clearError: true));
    } on Object catch (error) {
      emit(SessionState(
        phase: SessionPhase.ready,
        contexts: state.contexts,
        selected: previous,
        error: error.toString(),
      ));
    }
  }
}
