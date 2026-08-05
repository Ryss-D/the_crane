import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';

part 'history_cubit.freezed.dart';

/// RAT-3 paginated trip-history state, shared by both roles.
@freezed
abstract class HistoryState with _$HistoryState {
  const HistoryState._();

  const factory HistoryState({
    @Default(<Job>[]) List<Job> items,
    @Default(0) int total,
    @Default(true) bool isLoading,
    @Default(false) bool isLoadingMore,
    @Default(false) bool loadFailed,
  }) = _HistoryState;

  /// More pages exist beyond what's loaded.
  bool get hasMore => items.length < total;
}

/// RAT-3 — the caller's job history (customer or driver, per [role]), newest
/// first, loaded a page at a time via [JobsRepository.listHistory].
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({
    required JobsRepository jobsRepository,
    required this.role,
    this.pageSize = 20,
  })  : _repo = jobsRepository,
        super(const HistoryState());

  final JobsRepository _repo;
  final JobHistoryRole role;
  final int pageSize;

  /// Fetches the first page, replacing whatever was loaded before.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true, loadFailed: false));
    try {
      final page = await _repo.listHistory(
        role: role,
        limit: pageSize,
        offset: 0,
      );
      emit(state.copyWith(
        items: page.items,
        total: page.total,
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }

  /// Appends the next page. No-op while already loading or once everything
  /// is loaded.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.listHistory(
        role: role,
        limit: pageSize,
        offset: state.items.length,
      );
      emit(state.copyWith(
        items: [...state.items, ...page.items],
        total: page.total,
        isLoadingMore: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
