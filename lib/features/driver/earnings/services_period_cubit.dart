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

@freezed
abstract class ServicesPeriodState with _$ServicesPeriodState {
  const factory ServicesPeriodState({
    @Default(<ServicesPeriodSummary>[]) List<ServicesPeriodSummary> periods,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
  }) = _ServicesPeriodState;
}

/// DRV-6 — groups the driver's completed jobs by calendar day (local time),
/// showing a count and cash/commission totals per day. Day was picked over
/// week because `Job` only carries a single `completedAt` timestamp with no
/// backend-side period bucketing (JOB-5's `GET /v1/jobs` list is flat) —
/// grouping by day needs nothing beyond that timestamp, while a
/// locale-aware week boundary would need more than this client-side pass
/// can assume safely.
class ServicesPeriodCubit extends Cubit<ServicesPeriodState> {
  ServicesPeriodCubit({required JobsRepository jobsRepository})
      : _repo = jobsRepository,
        super(const ServicesPeriodState());

  final JobsRepository _repo;

  static const _pageSize = 100;

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

      final grouped = <DateTime, List<Job>>{};
      for (final job in jobs) {
        if (job.status != JobStatus.completed) continue;
        final day = _dayKey(job.completedAt ?? job.requestedAt);
        grouped.putIfAbsent(day, () => []).add(job);
      }

      final periods = grouped.entries.map((entry) {
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

      emit(state.copyWith(periods: periods, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }

  static DateTime _dayKey(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
