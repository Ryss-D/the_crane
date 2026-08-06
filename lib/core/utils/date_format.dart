/// Formats a [DateTime] as `dd/MM/yyyy HH:mm` in local time.
///
/// Deliberately not `intl`'s `DateFormat`: that requires
/// `initializeDateFormatting()` to be called for any non-`en_US` locale
/// (this app runs in `es`) before named month/weekday lookups work, which
/// nothing in the app currently does. A pure-digit pattern doesn't need
/// locale symbol data at all, so a tiny hand-rolled formatter avoids that
/// footgun entirely for the trip-history screens (`lib/features/shared/history/`).
String formatHistoryDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Formats a day-only [DateTime] as `dd/MM/yyyy` in local time (no
/// time-of-day) — used by DRV-6's per-day services grouping. Same
/// hand-rolled approach as [formatHistoryDate], for the same reason (no
/// `intl` locale-data initialization needed).
String formatDay(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}
