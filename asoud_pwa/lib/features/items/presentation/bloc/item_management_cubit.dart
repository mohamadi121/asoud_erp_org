import 'package:asoud_pwa/features/items/domain/item_gateway.dart';
import 'package:asoud_pwa/features/items/domain/item_models.dart';
import 'package:asoud_pwa/features/session/domain/work_context.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ItemPhase { initial, loading, ready, saving, failure }

class ItemManagementState extends Equatable {
  const ItemManagementState(
      {this.phase = ItemPhase.initial,
      this.snapshot = const ItemSnapshot(),
      this.draft,
      this.error});
  final ItemPhase phase;
  final ItemSnapshot snapshot;
  final ItemDraft? draft;
  final String? error;
  ItemManagementState copyWith(
          {ItemPhase? phase,
          ItemSnapshot? snapshot,
          ItemDraft? draft,
          String? error,
          bool clearDraft = false}) =>
      ItemManagementState(
          phase: phase ?? this.phase,
          snapshot: snapshot ?? this.snapshot,
          draft: clearDraft ? null : draft ?? this.draft,
          error: error);
  @override
  List<Object?> get props => [phase, snapshot, draft, error];
}

class ItemManagementCubit extends Cubit<ItemManagementState> {
  ItemManagementCubit(this.gateway, this.context)
      : super(const ItemManagementState());
  final ItemGateway gateway;
  final WorkContext context;
  Future<void> load({String search = ''}) async {
    emit(state.copyWith(phase: ItemPhase.loading));
    try {
      emit(state.copyWith(
          phase: ItemPhase.ready,
          snapshot: await gateway.load(context, search: search)));
    } catch (e) {
      emit(state.copyWith(phase: ItemPhase.failure, error: '$e'));
    }
  }

  void create() => emit(state.copyWith(draft: const ItemDraft()));
  Future<void> edit(String code) async {
    emit(state.copyWith(phase: ItemPhase.loading));
    try {
      emit(state.copyWith(
          phase: ItemPhase.ready, draft: await gateway.detail(context, code)));
    } catch (e) {
      emit(state.copyWith(phase: ItemPhase.failure, error: '$e'));
    }
  }

  void update(ItemDraft draft) => emit(state.copyWith(draft: draft));
  void cancel() => emit(state.copyWith(clearDraft: true));
  Future<void> save() async {
    final draft = state.draft;
    if (draft == null) return;
    emit(state.copyWith(phase: ItemPhase.saving));
    try {
      await gateway.save(context, draft);
      emit(state.copyWith(
          phase: ItemPhase.ready,
          snapshot: await gateway.load(context),
          clearDraft: true));
    } catch (e) {
      emit(state.copyWith(phase: ItemPhase.failure, error: '$e'));
    }
  }
}
