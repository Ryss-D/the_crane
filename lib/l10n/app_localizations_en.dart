// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The Crane';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle =>
      'Request a tow truck for your motorcycle or car in Medellín.';

  @override
  String get signInPhoneButton => 'Continue with phone';

  @override
  String get continueAsCustomer => 'Enter as customer';

  @override
  String get continueAsDriver => 'Enter as driver';

  @override
  String get customerHomeTitle => 'Request a tow';

  @override
  String get driverHomeTitle => 'Driver dashboard';

  @override
  String get mapPlaceholderBody => 'The Google Map will live here.';

  @override
  String get pickupFieldLabel => 'Pickup point';

  @override
  String get pickupFieldHint => 'Where is your vehicle?';

  @override
  String get dropoffFieldLabel => 'Destination';

  @override
  String get dropoffFieldHint => 'Where are we taking it?';

  @override
  String get vehicleTypeLabel => 'Vehicle type';

  @override
  String get vehicleMoto => 'Motorcycle';

  @override
  String get vehicleCar => 'Car';

  @override
  String get vehicleSuv => 'SUV';

  @override
  String get quotePrompt => 'Enter pickup and destination to get a quote.';

  @override
  String get quoteError => 'We could not calculate the fare. Please try again.';

  @override
  String quoteEtaMinutes(int minutes) {
    return 'Arrives in $minutes min';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get confirmRequestButton => 'Confirm request';

  @override
  String get matchingTitle => 'Finding your tow truck';

  @override
  String get matchingBody => 'We are contacting nearby drivers…';

  @override
  String get assignedTitle => 'Tow truck assigned!';

  @override
  String get assignedBody => 'Your driver is on the way to the pickup point.';

  @override
  String driverPlateLabel(String plate) {
    return 'Plate $plate';
  }

  @override
  String get noDriversTitle => 'No tow trucks available';

  @override
  String get noDriversBody =>
      'No drivers are available right now. Please try again.';

  @override
  String get retryButton => 'Retry';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get backToHomeButton => 'Back to home';

  @override
  String get truckTypeMotoOnly => 'Motorcycle tow truck';

  @override
  String get truckTypeCar => 'Car tow truck';

  @override
  String get truckTypeFlatbed => 'Flatbed';

  @override
  String get availabilityOffline => 'Offline';

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityOnJob => 'On a job';

  @override
  String get goAvailableButton => 'Go online';

  @override
  String get goOfflineButton => 'Go offline';

  @override
  String get offlineHint => 'Go online to receive job offers.';

  @override
  String get availableHint => 'Waiting for nearby offers…';

  @override
  String get blockedBannerUnverified =>
      'Your account is pending verification. You will not receive offers yet.';

  @override
  String get devTriggerOfferButton => 'Simulate offer (dev)';

  @override
  String get offerTitle => 'New job offer';

  @override
  String offerPickupDistance(String km) {
    return '$km km away from you';
  }

  @override
  String get fareLabel => 'Fare';

  @override
  String get offerCommissionLabel => 'Platform commission';

  @override
  String get offerEarningsLabel => 'Your earnings';

  @override
  String offerCountdown(int seconds) {
    return 'Expires in $seconds s';
  }

  @override
  String get acceptButton => 'Accept';

  @override
  String get rejectButton => 'Reject';

  @override
  String get activeJobTitle => 'Active job';

  @override
  String get statusRequested => 'Requested';

  @override
  String get statusMatching => 'Finding a driver';

  @override
  String get statusAssigned => 'Assigned';

  @override
  String get statusEnRoutePickup => 'En route to pickup';

  @override
  String get statusArrivedPickup => 'At the pickup point';

  @override
  String get statusLoading => 'Loading the vehicle';

  @override
  String get statusInTransit => 'En route to destination';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusNoDrivers => 'No drivers found';

  @override
  String get advanceEnRoutePickup => 'On my way';

  @override
  String get advanceArrivedPickup => 'I arrived';

  @override
  String get advanceLoading => 'Loading vehicle';

  @override
  String get advanceInTransit => 'Start trip';

  @override
  String get advanceDelivered => 'Delivered';

  @override
  String get advanceCompleted => 'Finish job';

  @override
  String get jobDoneBody => 'Job finished. Great work!';
}
