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
  String get signInPhoneLabel => 'Phone number';

  @override
  String get signInPhoneHint => '300 123 4567';

  @override
  String get signInPhoneButton => 'Send code';

  @override
  String get signInSendCodeError =>
      'We couldn\'t send the code. Check the number and try again.';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSentTo(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String get otpLabel => 'Verification code';

  @override
  String get otpHint => '123456';

  @override
  String get otpConfirmButton => 'Confirm';

  @override
  String get otpChangeNumber => 'Change number';

  @override
  String get otpConfirmError => 'Wrong code. Try again.';

  @override
  String get completeProfileTitle => 'What\'s your name?';

  @override
  String get completeProfileSubtitle =>
      'We use it so your driver or customer knows who you are.';

  @override
  String get completeProfileNameLabel => 'Full name';

  @override
  String get completeProfileSaveButton => 'Continue';

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
  String get availabilityBlocked => 'Blocked';

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
  String get blockedBannerAdmin =>
      'Your account is blocked. Contact support for details.';

  @override
  String get blockedBannerBalanceCap =>
      'Your owed balance exceeded the allowed cap. Settle your balance to go available again.';

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

  @override
  String get navigateButton => 'Navigate';

  @override
  String get cancelJobButton => 'Cancel job';

  @override
  String get cancelJobConfirmTitle => 'Cancel this job?';

  @override
  String get cancelJobConfirmBody =>
      'The job goes back to the dispatch pool for another driver to pick up.';

  @override
  String get rateTripButton => 'Rate trip';

  @override
  String get rateDialogTitle => 'How was your trip?';

  @override
  String get rateCommentHint => 'Comment (optional)';

  @override
  String get submitRatingButton => 'Submit rating';

  @override
  String get skipRatingButton => 'Skip';

  @override
  String get rateSubmitError =>
      'We could not submit your rating. Please try again.';

  @override
  String get historyTitle => 'Trip history';

  @override
  String get historyEmptyBody => 'You have no trips yet.';

  @override
  String get historyLoadError =>
      'We could not load your history. Please try again.';

  @override
  String get historyLoadMoreButton => 'Load more';

  @override
  String get historyDetailTitle => 'Trip detail';

  @override
  String get ratingsSectionTitle => 'Ratings';

  @override
  String get noRatingsBody => 'No ratings yet.';

  @override
  String get ratingFromCustomerLabel => 'Rating for the driver';

  @override
  String get ratingFromDriverLabel => 'Rating for the customer';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get becomeDriverMenuItem => 'Become a driver';

  @override
  String get becomeDriverTitle => 'Become a driver';

  @override
  String get becomeDriverIntro =>
      'Register your tow truck to start receiving jobs.';

  @override
  String get becomeDriverModeOwnTruck => 'I have my truck';

  @override
  String get becomeDriverModeInvite => 'I have an invite';

  @override
  String get becomeDriverInviteIntro =>
      'Enter the code the fleet owner shared with you.';

  @override
  String get inviteTokenFieldLabel => 'Invite code';

  @override
  String get inviteTokenFieldHint => '00000000-0000-0000-0000-000000000000';

  @override
  String get plateFieldLabel => 'Plate';

  @override
  String get plateFieldHint => 'ABC123';

  @override
  String get truckTypeFieldLabel => 'Truck type';

  @override
  String get capacityFieldLabel => 'Truck capacity';

  @override
  String get capacityMoto => 'Motorcycles';

  @override
  String get capacityCar => 'Cars';

  @override
  String get capacityBoth => 'Motorcycles and cars';

  @override
  String get licenseUrlFieldLabel => 'License document URL (optional)';

  @override
  String get truckPhotoUrlFieldLabel => 'Truck photo URL (optional)';

  @override
  String get becomeDriverSubmitButton => 'Submit registration';

  @override
  String get becomeDriverSubmitError =>
      'We could not complete registration. Please try again.';

  @override
  String get becomeFleetOwnerMenuItem => 'Create my fleet';

  @override
  String get becomeFleetOwnerTitle => 'Create your fleet';

  @override
  String get becomeFleetOwnerIntro =>
      'Give your fleet a name to start managing your trucks and drivers.';

  @override
  String get fleetNameFieldLabel => 'Fleet name';

  @override
  String get fleetNameFieldHint => 'Valley Tow Trucks';

  @override
  String get becomeFleetOwnerSubmitButton => 'Create fleet';

  @override
  String get becomeFleetOwnerSubmitError =>
      'We could not create your fleet. Please try again.';

  @override
  String get fleetHomeTitle => 'My fleet';

  @override
  String get fleetLoadError =>
      'We could not load your fleet. Please try again.';

  @override
  String get fleetEmptyBody =>
      'Your fleet has no trucks yet. Add one with its plate.';

  @override
  String get fleetTruckStatusUnassigned => 'No driver';

  @override
  String get fleetTruckDetailTitle => 'Truck detail';

  @override
  String get fleetTruckDriverLabel => 'Driver';

  @override
  String get fleetTruckStatusLabel => 'Status';

  @override
  String get addTruckTitle => 'Add truck';

  @override
  String get addTruckIntro =>
      'Look up a truck by its plate to add it to your fleet.';

  @override
  String get addTruckSearchButton => 'Search';

  @override
  String get addTruckNotFoundBody =>
      'We could not find a truck with that plate.';

  @override
  String get addTruckSearchError =>
      'We could not look up the truck. Please try again.';

  @override
  String get addTruckAlreadyClaimedBody =>
      'This truck already belongs to another fleet and cannot be added.';

  @override
  String get addTruckAttachButton => 'Add to my fleet';

  @override
  String get addTruckAttachError =>
      'We could not add the truck. Please try again.';

  @override
  String get detachTruckConfirmTitle => 'Remove truck from the fleet?';

  @override
  String get detachTruckConfirmBody =>
      'Its assigned driver will no longer belong to this fleet.';

  @override
  String get detachTruckButton => 'Remove from fleet';

  @override
  String get detachTruckError =>
      'We could not remove the truck. Please try again.';

  @override
  String get inviteDriverTitle => 'Invite driver';

  @override
  String get inviteDriverIntro =>
      'Invite a driver by phone number; their truck is ready for them to claim when they register.';

  @override
  String get invitePhoneFieldLabel => 'Driver\'s phone number';

  @override
  String get inviteSendButton => 'Send invite';

  @override
  String get inviteSendError =>
      'We could not send the invite. Check the details and try again.';

  @override
  String get pendingInvitesTitle => 'Pending invites';

  @override
  String get pendingInvitesEmptyBody => 'You have no pending invites.';

  @override
  String get pendingInvitesLoadError =>
      'We could not load the invites. Please try again.';

  @override
  String get fleetBalanceTitle => 'Fleet earnings';

  @override
  String get fleetBalanceOwedLabel => 'Consolidated owed balance';

  @override
  String get fleetBalanceMembersTitle => 'Breakdown by driver';

  @override
  String get fleetBalanceNoMembersBody =>
      'Your fleet has no drivers with a balance yet.';

  @override
  String get fleetBalanceLoadError =>
      'We could not load the fleet\'s earnings. Please try again.';

  @override
  String get cashPaymentPendingBody =>
      'Confirm you received the cash payment to finish the job.';

  @override
  String get cashConfirmButton => 'Paid in cash';

  @override
  String get cashPaymentConfirmError =>
      'We could not confirm the payment. Please try again.';

  @override
  String get waitingCashConfirmationBody =>
      'Waiting for the customer to confirm the cash payment.';

  @override
  String get savedVehiclesMenuItem => 'My saved vehicles';

  @override
  String get savedVehiclesTitle => 'Saved vehicles';

  @override
  String get noSavedVehiclesBody => 'You have no saved vehicles yet.';

  @override
  String get loadVehiclesError =>
      'We could not load your vehicles. Please try again.';

  @override
  String get addVehicleButton => 'Add vehicle';

  @override
  String get editVehicleTitle => 'Edit vehicle';

  @override
  String get vehicleMakeFieldLabel => 'Make (optional)';

  @override
  String get vehicleModelFieldLabel => 'Model (optional)';

  @override
  String get vehicleSaveButton => 'Save';

  @override
  String get vehicleSaveError =>
      'We could not save the vehicle. Please try again.';

  @override
  String get deleteVehicleConfirmTitle => 'Delete vehicle?';

  @override
  String get deleteVehicleConfirmBody => 'This action cannot be undone.';

  @override
  String get deleteButton => 'Delete';

  @override
  String get savedVehiclePickerLabel => 'Saved vehicle (optional)';

  @override
  String get earningsTitle => 'Earnings & balance';

  @override
  String get earningsOwedLabel => 'Owed balance';

  @override
  String get earningsCapLabel => 'Balance cap before availability is blocked';

  @override
  String get earningsSettlementsTitle => 'Recent settlements';

  @override
  String get earningsNoSettlementsBody => 'No settlements yet.';

  @override
  String get earningsLoadError =>
      'We could not load your earnings. Please try again.';

  @override
  String get jobCommissionLabel => 'Commission for this job';

  @override
  String get runningBalanceLabel => 'New owed balance';

  @override
  String get servicesPeriodTitle => 'Services per period';

  @override
  String get servicesPeriodEmptyBody => 'You have no completed services yet.';

  @override
  String get servicesPeriodLoadError =>
      'We could not load your services. Please try again.';

  @override
  String servicesCountLabel(int count) {
    return '$count services';
  }

  @override
  String get servicesEarningsLabel => 'Cash collected';

  @override
  String get servicesCommissionLabel => 'Commission';

  @override
  String get callDriverButton => 'Call driver';

  @override
  String get shareTripButton => 'Share trip';

  @override
  String get shareTripLinkCopied => 'Link copied to clipboard';
}
