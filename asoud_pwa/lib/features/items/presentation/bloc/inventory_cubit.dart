import 'package:asoud_pwa/features/items/domain/inventory_models.dart';
import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum InventoryPhase { initial, loading, ready, saving, failure }

class InventoryState extends Equatable {
  const InventoryState({
    this.phase = InventoryPhase.initial,
    this.workspace = const InventoryWorkspace(),
    this.error,
  });

  final InventoryPhase phase;
  final InventoryWorkspace workspace;
  final String? error;

  InventoryState copyWith({
    InventoryPhase? phase,
    InventoryWorkspace? workspace,
    String? error,
    bool clearError = false,
  }) =>
      InventoryState(
        phase: phase ?? this.phase,
        workspace: workspace ?? this.workspace,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [phase, workspace, error];
}

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit(this._gateway, this._context) : super(const InventoryState());

  final ItemGateway _gateway;
  final WorkContext _context;

  Future<void> load() async {
    emit(state.copyWith(phase: InventoryPhase.loading, clearError: true));
    try {
      emit(state.copyWith(
        phase: InventoryPhase.ready,
        workspace: await _gateway.loadInventory(_context),
        clearError: true,
      ));
    } on Object catch (error) {
      emit(state.copyWith(phase: InventoryPhase.failure, error: '$error'));
    }
  }

  Future<bool> save(InventorySettingDraft draft) async {
    if (state.phase == InventoryPhase.saving) return false;
    emit(state.copyWith(phase: InventoryPhase.saving, clearError: true));
    try {
      await _gateway.saveInventorySetting(_context, draft);
      emit(state.copyWith(
        phase: InventoryPhase.ready,
        workspace: await _gateway.loadInventory(_context),
        clearError: true,
      ));
      return true;
    } on Object catch (error) {
      emit(state.copyWith(phase: InventoryPhase.failure, error: '$error'));
      return false;
    }
  }
}
