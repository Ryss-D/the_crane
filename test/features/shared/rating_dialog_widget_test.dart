import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/jobs_repository.dart';
import 'package:the_crane/features/shared/rating/rating_dialog.dart';
import 'package:the_crane/l10n/app_localizations.dart';

/// RAT-1/RAT-2 test double: records every `submitRating` call and can be
/// told to reject the *next* one, mirroring `RejectingOnceJobsRepository`'s
/// shape (`test/support/`). `noSuchMethod` mirrors
/// `services_period_cubit_test.dart`'s `SeededHistoryJobsRepository`: only
/// the one method `_RatingDialog` actually calls needs a real body.
class _StubRatingJobs implements JobsRepository {
  bool rejectNext = false;
  final List<({int stars, String? comment})> submitted = [];

  @override
  Future<void> submitRating(
    String jobId, {
    required int stars,
    String? comment,
  }) async {
    if (rejectNext) {
      rejectNext = false;
      throw StateError('boom');
    }
    submitted.add((stars: stars, comment: comment));
  }

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed by these tests');
}

/// Hosts a button that opens the dialog exactly like `MatchingScreen`/
/// `ActiveJobScreen` do, and surfaces the `Future<bool>` result as text so
/// tests can assert on it without reaching into `showDialog`'s internals.
class _Harness extends StatefulWidget {
  const _Harness({required this.jobsRepository});

  final JobsRepository jobsRepository;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<JobsRepository>.value(
      value: widget.jobsRepository,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  key: const Key('openRatingDialog'),
                  onPressed: () async {
                    final result =
                        await showRatingDialog(context, jobId: 'job-1');
                    setState(() => _result = result);
                  },
                  child: const Text('Open'),
                ),
                Text('result: $_result'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('RatingDialog (RAT-1/RAT-2)', () {
    testWidgets('stars fill up to the tapped index, submit disabled at zero',
        (tester) async {
      final jobs = _StubRatingJobs();
      await tester.pumpWidget(_Harness(jobsRepository: jobs));
      await tester.tap(find.byKey(const Key('openRatingDialog')));
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo estuvo tu viaje?'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submitRatingButton')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('ratingStar4')));
      await tester.pump();

      IconData starIcon(int i) =>
          (tester.widget<IconButton>(find.byKey(Key('ratingStar$i'))).icon
                  as Icon)
              .icon!;
      for (var i = 1; i <= 4; i++) {
        expect(starIcon(i), Icons.star);
      }
      expect(starIcon(5), Icons.star_border);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submitRatingButton')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'submitting stars + a comment calls submitRating and pops true',
        (tester) async {
      final jobs = _StubRatingJobs();
      await tester.pumpWidget(_Harness(jobsRepository: jobs));
      await tester.tap(find.byKey(const Key('openRatingDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ratingStar5')));
      await tester.enterText(
        find.byKey(const Key('ratingCommentField')),
        'Excelente servicio',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('submitRatingButton')));
      await tester.pumpAndSettle();

      expect(jobs.submitted, [(stars: 5, comment: 'Excelente servicio')]);
      expect(find.text('¿Cómo estuvo tu viaje?'), findsNothing);
      expect(find.text('result: true'), findsOneWidget);
    });

    testWidgets(
        'a submit failure surfaces the error and keeps the dialog open; '
        'retrying succeeds', (tester) async {
      final jobs = _StubRatingJobs()..rejectNext = true;
      await tester.pumpWidget(_Harness(jobsRepository: jobs));
      await tester.tap(find.byKey(const Key('openRatingDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ratingStar3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submitRatingButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos enviar tu calificación. Intenta de nuevo.'),
        findsOneWidget,
      );
      // Still open -- the dialog didn't pop on failure.
      expect(find.text('¿Cómo estuvo tu viaje?'), findsOneWidget);
      expect(jobs.submitted, isEmpty);

      await tester.tap(find.byKey(const Key('submitRatingButton')));
      await tester.pumpAndSettle();

      expect(jobs.submitted, [(stars: 3, comment: '')]);
      expect(find.text('¿Cómo estuvo tu viaje?'), findsNothing);
      expect(find.text('result: true'), findsOneWidget);
    });

    testWidgets('skip pops false without submitting anything',
        (tester) async {
      final jobs = _StubRatingJobs();
      await tester.pumpWidget(_Harness(jobsRepository: jobs));
      await tester.tap(find.byKey(const Key('openRatingDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('skipRatingButton')));
      await tester.pumpAndSettle();

      expect(jobs.submitted, isEmpty);
      expect(find.text('result: false'), findsOneWidget);
    });

    testWidgets('shows a spinner and disables inputs while submitting',
        (tester) async {
      final jobs = _SlowRatingJobs();
      await tester.pumpWidget(_Harness(jobsRepository: jobs));
      await tester.tap(find.byKey(const Key('openRatingDialog')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ratingStar2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submitRatingButton')));
      await tester.pump(); // enters the submitting state, doesn't resolve yet

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ratingCommentField')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('skipRatingButton')))
            .onPressed,
        isNull,
      );

      await jobs.release();
      await tester.pumpAndSettle();
      expect(find.text('result: true'), findsOneWidget);
    });
  });
}

/// A `submitRating` that hangs until [release] is called -- lets a test
/// observe the in-flight `_submitting` state deterministically instead of
/// racing a real delay.
class _SlowRatingJobs implements JobsRepository {
  final _completer = Completer<void>();

  Future<void> release() {
    _completer.complete();
    return _completer.future;
  }

  @override
  Future<void> submitRating(
    String jobId, {
    required int stars,
    String? comment,
  }) => _completer.future;

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed by these tests');
}
