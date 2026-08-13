import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/notifications/push_notifications.dart';
import 'package:the_crane/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('es'));
  });

  test('job_offer maps to the job-offer title/body pair', () {
    final (title, body) = notificationTextFor('job_offer', l10n);

    expect(title, l10n.pushJobOfferTitle);
    expect(body, l10n.pushJobOfferBody);
  });

  test('job_event maps to the job-event title/body pair', () {
    final (title, body) = notificationTextFor('job_event', l10n);

    expect(title, l10n.pushJobEventTitle);
    expect(body, l10n.pushJobEventBody);
  });

  test('an unrecognized type falls back to the generic pair — forward '
      'compatible with a server-added type this client build predates', () {
    final (title, body) = notificationTextFor('something_new', l10n);

    expect(title, l10n.pushGenericTitle);
    expect(body, l10n.pushGenericBody);
  });

  test('a null type (malformed/missing data payload) also falls back to '
      'the generic pair', () {
    final (title, body) = notificationTextFor(null, l10n);

    expect(title, l10n.pushGenericTitle);
    expect(body, l10n.pushGenericBody);
  });
}
