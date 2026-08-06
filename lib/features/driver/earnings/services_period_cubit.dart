import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';

part 'services_period_cubit.freezed.dart';

/// One day's worth of completed services (DRV-6) — a purely client-side
/// grouping over `JobsRepository.listHistory`, no new backend endpoint.
@freezed
abstract class ServicesPeriodSummary with _$ServicesPeriodSummary {
  const factory ServicesPeriodSummary({
    required DateTime day,
    required int jobCount,
    required int totalFare,
    required int totalCommission,
  }) = _ServicesPeriodSummary;
}

/// DRV-6 period selector. `week`/`month` are rolling windows anchored on
/// today (last 7 days / current calendar month) rather than
/// locale-anchored calendar weeks — the same "nothing this client-side
/// pass can assume safely" reasoning that originally picked day-grouping
/// over week-grouping applies to a Monday-vs-Sunday week start too, so
/// this sidesteps it entirely.
enum ServicesPeriodFilter { today, week, month, custom }

@freezed
abstract class ServicesPeriodState with _$ServicesPeriodState {
  const ServicesPeriodState._();

  const factory ServicesPeriodState({
    @Default(<ServicesPeriodSummary>[]) List<ServicesPeriodSummary> periods,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
    @Default(ServicesPeriodFilter.today) ServicesPeriodFilter filter,
    DateTime? customStart,
    DateTime? customEnd,
  }) = _ServicesPeriodState;

  /// Totals across every day currently in [periods] (i.e. for whichever
  /// [filter] is active) — the count/list/chart all update from the same
  /// filtered set, so these three are simply reduced from it.
  int get totalJobCount => periods.fold(0, (sum, p) => sum + p.jobCount);
  int get totalFare => periods.fold(0, (sum, p) => sum + p.totalFare);
  int get totalCommission =>
      periods.fold(0, (sum, p) => sum + p.totalCommission);

  /// The largest single day's fare in [periods] — backs the bar-list's
  /// relative bar widths (this app has no charting package; a plain
  /// proportional-width bar per row is the "reasonable substitute" for one
  /// rather than adding a dependency for it).
  int get maxDayFare =>
      periods.fold(0, (max, p) => p.totalFare > max ? p.totalFare : max);
}

/// DRV-6 — groups the driver's completed jobs by calendar day (local time)
/// and shows a Today/Week/Month/Custom-range selector over that grouping;
/// switching the filter re-slices the same in-memory job list rather than
/// re-fetching (`JobsRepository.listHistory` has no date-range filtering to
/// push this down to server-side anyway).
class ServicesPeriodCubit extends Cubit<ServicesPeriodState> {
  ServicesPeriodCubit({required JobsRepository jobsRepository})
      : _repo = jobsRepository,
        super(
          ServicesPeriodState(
            filter: _lastFilter,
            customStart: _lastCustomStart,
            customEnd: _lastCustomEnd,
          ),
        );

  final JobsRepository _repo;
  List<Job> _completedJobs = const [];

  static const _pageSize = 100;

  /// DRV-6 "persists on reopen": this cubit is recreated every time the
  /// screen is (re)navigated to (see the `services` route in
  /// `lib/app/router.dart`), so a plain instance field wouldn't survive
  /// leaving and coming back — this app has no persistence layer
  /// (shared_preferences or similar) at all yet, so static in-memory state
  /// is the simplest honest way to remember the driver's last filter/range
  /// across that. Resets on a full app restart, unlike a real persisted
  /// preference would.
  static ServicesPeriodFilter _lastFilter = ServicesPeriodFilter.today;
  static DateTime? _lastCustomStart;
  static DateTime? _lastCustomEnd;

  /// Test-only: the static "remembered" state above otherwise leaks
  /// between tests that run in the same isolate (i.e. the same test file).
  @visibleForTesting
  static void resetRememberedFilterForTest() {
    _lastFilter = ServicesPeriodFilter.today;
    _lastCustomStart = null;
    _lastCustomEnd = null;
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, loadFailed: false));
    try {
      final jobs = <Job>[];
      var offset = 0;
      while (true) {
        final page = await _repo.listHistory(
          role: JobHistoryRole.driver,
          limit: _pageSize,
          offset: offset,
        );
        jobs.addAll(page.items);
        offset += page.items.length;
        if (page.items.length < _pageSize || jobs.length >= page.total) break;
      }
      _completedJobs = jobs.where((j) => j.status == JobStatus.completed).toList();
      emit(state.copyWith(periods: _buildPeriods(state), isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }

  /// Switches to [filter] (ignored for `custom` — use [setCustomRange],
  /// which needs the actual dates) and re-slices the already-loaded jobs.
  void setFilter(ServicesPeriodFilter filter) {
    if (filter == ServicesPeriodFilter.custom || filter == state.filter) {
      return;
    }
    _lastFilter = filter;
    final next = state.copyWith(filter: filter);
    emit(next.copyWith(periods: _buildPeriods(next)));
  }

  /// Sets the custom range (day-granularity, inclusive both ends) and
  /// switches to it. Remembers both for next time this screen opens (see
  /// the static fields' doc comment above).
  void setCustomRange(DateTime start, DateTime end) {
    final normalizedStart = _dayKey(start);
    final normalizedEnd = _dayKey(end);
    _lastFilter = ServicesPeriodFilter.custom;
    _lastCustomStart = normalizedStart;
    _lastCustomEnd = normalizedEnd;
    final next = state.copyWith(
      filter: ServicesPeriodFilter.custom,
      customStart: normalizedStart,
      customEnd: normalizedEnd,
    );
    emit(next.copyWith(periods: _buildPeriods(next)));
  }

  List<ServicesPeriodSummary> _buildPeriods(ServicesPeriodState forState) {
    final today = _dayKey(DateTime.now());
    bool inRange(DateTime day) => switch (forState.filter) {
          ServicesPeriodFilter.today => day == today,
          ServicesPeriodFilter.week =>
            !day.isBefore(today.subtract(const Duration(days: 6))) &&
                !day.isAfter(today),
          ServicesPeriodFilter.month =>
            day.year == today.year && day.month == today.month,
          ServicesPeriodFilter.custom =>
            forState.customStart != null &&
                forState.customEnd != null &&
                !day.isBefore(forState.customStart!) &&
                !day.isAfter(forState.customEnd!),
        };

    final grouped = <DateTime, List<Job>>{};
    for (final job in _completedJobs) {
      final day = _dayKey(job.completedAt ?? job.requestedAt);
      if (!inRange(day)) continue;
      grouped.putIfAbsent(day, () => []).add(job);
    }

    return grouped.entries.map((entry) {
      final fare = entry.value.fold<int>(
        0,
        (sum, job) => sum + (job.finalPrice ?? job.quotedPrice),
      );
      // TODO(JOB-2/LED-1): same flat-15% approximation used throughout
      // the driver app (offer preview, DRV-4's per-job commission) until
      // the backend returns real per-job/period commission figures.
      final commission = (fare * 0.15 / 100).round() * 100;
      return ServicesPeriodSummary(
        day: entry.key,
        jobCount: entry.value.length,
        totalFare: fare,
        totalCommission: commission,
      );
    }).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
  }

  static DateTime _dayKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
