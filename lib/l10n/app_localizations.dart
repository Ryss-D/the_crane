import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Application title
  ///
  /// In es, this message translates to:
  /// **'The Crane'**
  String get appTitle;

  /// Headline on the sign-in screen
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get signInTitle;

  /// Supporting copy on the sign-in screen
  ///
  /// In es, this message translates to:
  /// **'Pide una grúa para tu moto o carro en Medellín.'**
  String get signInSubtitle;

  /// Phone entry field label on the sign-in screen
  ///
  /// In es, this message translates to:
  /// **'Número de celular'**
  String get signInPhoneLabel;

  /// Phone entry field placeholder (local format, +57 is added automatically)
  ///
  /// In es, this message translates to:
  /// **'300 123 4567'**
  String get signInPhoneHint;

  /// Primary sign-in button — sends the OTP
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get signInPhoneButton;

  /// Shown when sending the OTP fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos enviar el código. Verifica el número e intenta de nuevo.'**
  String get signInSendCodeError;

  /// Headline on the OTP entry screen
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código'**
  String get otpTitle;

  /// Tells the user where the code was sent
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código a {phone}'**
  String otpSentTo(String phone);

  /// OTP code entry field label
  ///
  /// In es, this message translates to:
  /// **'Código de verificación'**
  String get otpLabel;

  /// OTP code entry field placeholder
  ///
  /// In es, this message translates to:
  /// **'123456'**
  String get otpHint;

  /// Confirms the entered OTP code
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get otpConfirmButton;

  /// Goes back to the phone entry screen
  ///
  /// In es, this message translates to:
  /// **'Cambiar número'**
  String get otpChangeNumber;

  /// Shown when the entered OTP code is wrong
  ///
  /// In es, this message translates to:
  /// **'Código incorrecto. Intenta de nuevo.'**
  String get otpConfirmError;

  /// Headline on the profile-completion screen
  ///
  /// In es, this message translates to:
  /// **'¿Cómo te llamas?'**
  String get completeProfileTitle;

  /// Supporting copy on the profile-completion screen
  ///
  /// In es, this message translates to:
  /// **'Lo usamos para que tu conductor o cliente sepa quién eres.'**
  String get completeProfileSubtitle;

  /// Name entry field label
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get completeProfileNameLabel;

  /// Saves the name and continues into the app
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get completeProfileSaveButton;

  /// Customer request screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Pedir grúa'**
  String get customerHomeTitle;

  /// Driver home app bar title
  ///
  /// In es, this message translates to:
  /// **'Panel del conductor'**
  String get driverHomeTitle;

  /// Label inside the map placeholder widget (pending FND-6)
  ///
  /// In es, this message translates to:
  /// **'Aquí irá el mapa de Google Maps.'**
  String get mapPlaceholderBody;

  /// Label for the pickup location field
  ///
  /// In es, this message translates to:
  /// **'Punto de recogida'**
  String get pickupFieldLabel;

  /// Hint for the pickup location field
  ///
  /// In es, this message translates to:
  /// **'¿Dónde está tu vehículo?'**
  String get pickupFieldHint;

  /// Label for the dropoff location field
  ///
  /// In es, this message translates to:
  /// **'Destino'**
  String get dropoffFieldLabel;

  /// Hint for the dropoff location field
  ///
  /// In es, this message translates to:
  /// **'¿A dónde lo llevamos?'**
  String get dropoffFieldHint;

  /// Heading above the vehicle type selector
  ///
  /// In es, this message translates to:
  /// **'Tipo de vehículo'**
  String get vehicleTypeLabel;

  /// Vehicle type: motorcycle
  ///
  /// In es, this message translates to:
  /// **'Moto'**
  String get vehicleMoto;

  /// Vehicle type: car
  ///
  /// In es, this message translates to:
  /// **'Carro'**
  String get vehicleCar;

  /// Vehicle type: SUV
  ///
  /// In es, this message translates to:
  /// **'SUV'**
  String get vehicleSuv;

  /// Quote card empty state, before both addresses are set
  ///
  /// In es, this message translates to:
  /// **'Ingresa la recogida y el destino para cotizar.'**
  String get quotePrompt;

  /// Quote card error state
  ///
  /// In es, this message translates to:
  /// **'No pudimos calcular la tarifa. Intenta de nuevo.'**
  String get quoteError;

  /// Pickup ETA shown on the quote card
  ///
  /// In es, this message translates to:
  /// **'Llega en {minutes} min'**
  String quoteEtaMinutes(int minutes);

  /// Distance in kilometers (pre-formatted number)
  ///
  /// In es, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// Button that creates the job from the current quote
  ///
  /// In es, this message translates to:
  /// **'Confirmar solicitud'**
  String get confirmRequestButton;

  /// Title of the matching/searching state (CUS-3)
  ///
  /// In es, this message translates to:
  /// **'Buscando tu grúa'**
  String get matchingTitle;

  /// Body of the matching/searching state
  ///
  /// In es, this message translates to:
  /// **'Estamos contactando a los conductores cercanos…'**
  String get matchingBody;

  /// Title when a driver is assigned
  ///
  /// In es, this message translates to:
  /// **'¡Grúa asignada!'**
  String get assignedTitle;

  /// Body when a driver is assigned
  ///
  /// In es, this message translates to:
  /// **'Tu conductor va en camino al punto de recogida.'**
  String get assignedBody;

  /// Truck plate on the assigned-driver card
  ///
  /// In es, this message translates to:
  /// **'Placa {plate}'**
  String driverPlateLabel(String plate);

  /// Title of the no-drivers state
  ///
  /// In es, this message translates to:
  /// **'Sin grúas disponibles'**
  String get noDriversTitle;

  /// Body of the no-drivers state
  ///
  /// In es, this message translates to:
  /// **'Por ahora no hay conductores disponibles. Intenta de nuevo.'**
  String get noDriversBody;

  /// Generic retry button
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retryButton;

  /// Generic cancel button
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelButton;

  /// Button returning to the role home screen
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get backToHomeButton;

  /// Truck type: motorcycle-only tow truck
  ///
  /// In es, this message translates to:
  /// **'Grúa de motos'**
  String get truckTypeMotoOnly;

  /// Truck type: car tow truck
  ///
  /// In es, this message translates to:
  /// **'Grúa de carros'**
  String get truckTypeCar;

  /// Truck type: flatbed
  ///
  /// In es, this message translates to:
  /// **'Planchón'**
  String get truckTypeFlatbed;

  /// Driver status: offline
  ///
  /// In es, this message translates to:
  /// **'Desconectado'**
  String get availabilityOffline;

  /// Driver status: available
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get availabilityAvailable;

  /// Driver status: on an active job
  ///
  /// In es, this message translates to:
  /// **'En servicio'**
  String get availabilityOnJob;

  /// Button to go available
  ///
  /// In es, this message translates to:
  /// **'Conectarme'**
  String get goAvailableButton;

  /// Button to go offline
  ///
  /// In es, this message translates to:
  /// **'Desconectarme'**
  String get goOfflineButton;

  /// Hint under the status label while offline
  ///
  /// In es, this message translates to:
  /// **'Conéctate para recibir ofertas de servicio.'**
  String get offlineHint;

  /// Hint under the status label while available
  ///
  /// In es, this message translates to:
  /// **'Esperando ofertas cercanas…'**
  String get availableHint;

  /// Banner when the driver is not yet verified by an admin
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está pendiente de verificación. No recibirás ofertas todavía.'**
  String get blockedBannerUnverified;

  /// Dev-only button that simulates an incoming offer
  ///
  /// In es, this message translates to:
  /// **'Simular oferta (dev)'**
  String get devTriggerOfferButton;

  /// Incoming offer sheet title
  ///
  /// In es, this message translates to:
  /// **'Nueva oferta de servicio'**
  String get offerTitle;

  /// Distance from the driver to the pickup point
  ///
  /// In es, this message translates to:
  /// **'A {km} km de ti'**
  String offerPickupDistance(String km);

  /// Fare amount label
  ///
  /// In es, this message translates to:
  /// **'Tarifa'**
  String get fareLabel;

  /// Platform commission label on the offer sheet
  ///
  /// In es, this message translates to:
  /// **'Comisión plataforma'**
  String get offerCommissionLabel;

  /// Driver net earnings label on the offer sheet
  ///
  /// In es, this message translates to:
  /// **'Tu ganancia'**
  String get offerEarningsLabel;

  /// Offer TTL countdown
  ///
  /// In es, this message translates to:
  /// **'Expira en {seconds} s'**
  String offerCountdown(int seconds);

  /// Accept the incoming offer
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get acceptButton;

  /// Reject the incoming offer
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get rejectButton;

  /// Active job screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Servicio activo'**
  String get activeJobTitle;

  /// Job status: requested
  ///
  /// In es, this message translates to:
  /// **'Solicitada'**
  String get statusRequested;

  /// Job status: matching
  ///
  /// In es, this message translates to:
  /// **'Buscando conductor'**
  String get statusMatching;

  /// Job status: assigned
  ///
  /// In es, this message translates to:
  /// **'Asignada'**
  String get statusAssigned;

  /// Job status: en route to pickup
  ///
  /// In es, this message translates to:
  /// **'En camino a la recogida'**
  String get statusEnRoutePickup;

  /// Job status: arrived at pickup
  ///
  /// In es, this message translates to:
  /// **'En el punto de recogida'**
  String get statusArrivedPickup;

  /// Job status: loading the vehicle
  ///
  /// In es, this message translates to:
  /// **'Cargando el vehículo'**
  String get statusLoading;

  /// Job status: in transit
  ///
  /// In es, this message translates to:
  /// **'En ruta al destino'**
  String get statusInTransit;

  /// Job status: delivered
  ///
  /// In es, this message translates to:
  /// **'Entregada'**
  String get statusDelivered;

  /// Job status: completed
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get statusCompleted;

  /// Job status: cancelled
  ///
  /// In es, this message translates to:
  /// **'Cancelada'**
  String get statusCancelled;

  /// Job status: no drivers found
  ///
  /// In es, this message translates to:
  /// **'Sin conductores'**
  String get statusNoDrivers;

  /// Driver action: start driving to the pickup
  ///
  /// In es, this message translates to:
  /// **'En camino'**
  String get advanceEnRoutePickup;

  /// Driver action: arrived at pickup
  ///
  /// In es, this message translates to:
  /// **'Llegué'**
  String get advanceArrivedPickup;

  /// Driver action: start loading the vehicle
  ///
  /// In es, this message translates to:
  /// **'Cargando vehículo'**
  String get advanceLoading;

  /// Driver action: start the trip to the dropoff
  ///
  /// In es, this message translates to:
  /// **'En ruta'**
  String get advanceInTransit;

  /// Driver action: vehicle delivered
  ///
  /// In es, this message translates to:
  /// **'Entregado'**
  String get advanceDelivered;

  /// Driver action: finish the job (cash collected)
  ///
  /// In es, this message translates to:
  /// **'Finalizar servicio'**
  String get advanceCompleted;

  /// Shown on the active job screen once completed
  ///
  /// In es, this message translates to:
  /// **'Servicio finalizado. ¡Buen trabajo!'**
  String get jobDoneBody;

  /// Opens the RAT-2 rating dialog after a job is completed
  ///
  /// In es, this message translates to:
  /// **'Calificar viaje'**
  String get rateTripButton;

  /// Title of the star-rating dialog
  ///
  /// In es, this message translates to:
  /// **'¿Cómo estuvo tu viaje?'**
  String get rateDialogTitle;

  /// Hint for the optional rating comment field
  ///
  /// In es, this message translates to:
  /// **'Comentario (opcional)'**
  String get rateCommentHint;

  /// Submits the rating dialog
  ///
  /// In es, this message translates to:
  /// **'Enviar calificación'**
  String get submitRatingButton;

  /// Skips the rating dialog without submitting
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get skipRatingButton;

  /// Shown in the rating dialog when submission fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos enviar tu calificación. Intenta de nuevo.'**
  String get rateSubmitError;

  /// Trip history screen app bar title, and the nav button tooltip
  ///
  /// In es, this message translates to:
  /// **'Historial de viajes'**
  String get historyTitle;

  /// Trip history empty state
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes viajes.'**
  String get historyEmptyBody;

  /// Trip history load error state
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tu historial. Intenta de nuevo.'**
  String get historyLoadError;

  /// Loads the next page of trip history
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get historyLoadMoreButton;

  /// Trip history detail screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Detalle del viaje'**
  String get historyDetailTitle;

  /// Heading above a job's ratings on the history detail screen
  ///
  /// In es, this message translates to:
  /// **'Calificaciones'**
  String get ratingsSectionTitle;

  /// Shown when a job has no ratings yet
  ///
  /// In es, this message translates to:
  /// **'Sin calificaciones todavía.'**
  String get noRatingsBody;

  /// Label for a rating the customer left for the driver
  ///
  /// In es, this message translates to:
  /// **'Calificación al conductor'**
  String get ratingFromCustomerLabel;

  /// Label for a rating the driver left for the customer
  ///
  /// In es, this message translates to:
  /// **'Calificación al cliente'**
  String get ratingFromDriverLabel;

  /// Settings screen app bar title, and the nav button tooltip
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// Settings menu item leading to the AUTH-5 driver registration screen
  ///
  /// In es, this message translates to:
  /// **'Convertirme en conductor'**
  String get becomeDriverMenuItem;

  /// Become-a-driver screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Conviértete en conductor'**
  String get becomeDriverTitle;

  /// Become-a-driver screen intro copy
  ///
  /// In es, this message translates to:
  /// **'Registra tu grúa para empezar a recibir servicios.'**
  String get becomeDriverIntro;

  /// Truck plate field label
  ///
  /// In es, this message translates to:
  /// **'Placa'**
  String get plateFieldLabel;

  /// Truck plate field placeholder
  ///
  /// In es, this message translates to:
  /// **'ABC123'**
  String get plateFieldHint;

  /// Truck type selector label on the become-a-driver screen
  ///
  /// In es, this message translates to:
  /// **'Tipo de grúa'**
  String get truckTypeFieldLabel;

  /// Truck capacity selector label on the become-a-driver screen
  ///
  /// In es, this message translates to:
  /// **'Capacidad de la grúa'**
  String get capacityFieldLabel;

  /// Truck capacity: motorcycles only
  ///
  /// In es, this message translates to:
  /// **'Motos'**
  String get capacityMoto;

  /// Truck capacity: cars only
  ///
  /// In es, this message translates to:
  /// **'Carros'**
  String get capacityCar;

  /// Truck capacity: both motorcycles and cars
  ///
  /// In es, this message translates to:
  /// **'Motos y carros'**
  String get capacityBoth;

  /// Optional driver license document URL field
  ///
  /// In es, this message translates to:
  /// **'URL de la licencia (opcional)'**
  String get licenseUrlFieldLabel;

  /// Optional truck photo URL field
  ///
  /// In es, this message translates to:
  /// **'URL de foto de la grúa (opcional)'**
  String get truckPhotoUrlFieldLabel;

  /// Submits the become-a-driver registration form
  ///
  /// In es, this message translates to:
  /// **'Enviar registro'**
  String get becomeDriverSubmitButton;

  /// Shown when driver registration fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar el registro. Intenta de nuevo.'**
  String get becomeDriverSubmitError;

  /// Settings menu item leading to the FLT-1 fleet creation screen
  ///
  /// In es, this message translates to:
  /// **'Crear mi flota'**
  String get becomeFleetOwnerMenuItem;

  /// Become-a-fleet-owner screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Crea tu flota'**
  String get becomeFleetOwnerTitle;

  /// Become-a-fleet-owner screen intro copy
  ///
  /// In es, this message translates to:
  /// **'Dale un nombre a tu flota para empezar a administrar tus grúas y conductores.'**
  String get becomeFleetOwnerIntro;

  /// Fleet name field label
  ///
  /// In es, this message translates to:
  /// **'Nombre de la flota'**
  String get fleetNameFieldLabel;

  /// Fleet name field placeholder
  ///
  /// In es, this message translates to:
  /// **'Grúas del Valle'**
  String get fleetNameFieldHint;

  /// Submits the become-a-fleet-owner form
  ///
  /// In es, this message translates to:
  /// **'Crear flota'**
  String get becomeFleetOwnerSubmitButton;

  /// Shown when fleet creation fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos crear tu flota. Intenta de nuevo.'**
  String get becomeFleetOwnerSubmitError;

  /// FLT-3: fleet-owner home ('Mi flota') screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Mi flota'**
  String get fleetHomeTitle;

  /// FLT-3: shown when loading the fleet fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tu flota. Intenta de nuevo.'**
  String get fleetLoadError;

  /// FLT-3: shown when the fleet has no trucks yet
  ///
  /// In es, this message translates to:
  /// **'Tu flota aún no tiene grúas. Agrega una con su placa.'**
  String get fleetEmptyBody;

  /// FLT-3: per-truck status label when the truck has no driver assigned yet
  ///
  /// In es, this message translates to:
  /// **'Sin conductor'**
  String get fleetTruckStatusUnassigned;

  /// CUS-5: shown on the assigned-driver card once the job is delivered, prompting cash-payment confirmation
  ///
  /// In es, this message translates to:
  /// **'Confirma que recibiste el pago en efectivo para finalizar el servicio.'**
  String get cashPaymentPendingBody;

  /// CUS-5: confirms cash payment was received, completing the job
  ///
  /// In es, this message translates to:
  /// **'Pagado en efectivo'**
  String get cashConfirmButton;

  /// CUS-5: shown when confirm-delivery fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos confirmar el pago. Intenta de nuevo.'**
  String get cashPaymentConfirmError;

  /// DRV-4: shown to the driver once a job is delivered, since only the customer can complete it
  ///
  /// In es, this message translates to:
  /// **'Esperando que el cliente confirme el pago en efectivo.'**
  String get waitingCashConfirmationBody;

  /// Settings menu item leading to the CUS-6 saved-vehicles screen
  ///
  /// In es, this message translates to:
  /// **'Mis vehículos guardados'**
  String get savedVehiclesMenuItem;

  /// Saved-vehicles screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Vehículos guardados'**
  String get savedVehiclesTitle;

  /// Saved-vehicles empty state
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes vehículos guardados.'**
  String get noSavedVehiclesBody;

  /// Saved-vehicles load error state
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus vehículos. Intenta de nuevo.'**
  String get loadVehiclesError;

  /// Add-vehicle FAB tooltip and form dialog title
  ///
  /// In es, this message translates to:
  /// **'Agregar vehículo'**
  String get addVehicleButton;

  /// Edit-vehicle form dialog title
  ///
  /// In es, this message translates to:
  /// **'Editar vehículo'**
  String get editVehicleTitle;

  /// Saved-vehicle make field label
  ///
  /// In es, this message translates to:
  /// **'Marca (opcional)'**
  String get vehicleMakeFieldLabel;

  /// Saved-vehicle model field label
  ///
  /// In es, this message translates to:
  /// **'Modelo (opcional)'**
  String get vehicleModelFieldLabel;

  /// Saves the vehicle form
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get vehicleSaveButton;

  /// Shown when creating/updating a saved vehicle fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar el vehículo. Intenta de nuevo.'**
  String get vehicleSaveError;

  /// Delete-vehicle confirmation dialog title
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar vehículo?'**
  String get deleteVehicleConfirmTitle;

  /// Delete-vehicle confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer.'**
  String get deleteVehicleConfirmBody;

  /// Generic delete/confirm-delete button
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteButton;

  /// CUS-6: label above the saved-vehicle picker on the request screen
  ///
  /// In es, this message translates to:
  /// **'Vehículo guardado (opcional)'**
  String get savedVehiclePickerLabel;

  /// DRV-5: earnings/balance screen app bar title, and the nav button tooltip
  ///
  /// In es, this message translates to:
  /// **'Ganancias y saldo'**
  String get earningsTitle;

  /// DRV-5: label above the driver's owed commission balance
  ///
  /// In es, this message translates to:
  /// **'Saldo pendiente'**
  String get earningsOwedLabel;

  /// DRV-5: label above the balance cap, when the platform has one configured
  ///
  /// In es, this message translates to:
  /// **'Límite de saldo antes de bloquear disponibilidad'**
  String get earningsCapLabel;

  /// DRV-5: heading above the recent-settlements list
  ///
  /// In es, this message translates to:
  /// **'Liquidaciones recientes'**
  String get earningsSettlementsTitle;

  /// DRV-5: shown when there are no recent settlements
  ///
  /// In es, this message translates to:
  /// **'Aún no hay liquidaciones.'**
  String get earningsNoSettlementsBody;

  /// DRV-5: shown when loading the balance fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus ganancias. Intenta de nuevo.'**
  String get earningsLoadError;

  /// DRV-4: label for the commission accrued on a just-completed job
  ///
  /// In es, this message translates to:
  /// **'Comisión de este servicio'**
  String get jobCommissionLabel;

  /// DRV-4: label for the driver's updated running balance after a job completes
  ///
  /// In es, this message translates to:
  /// **'Nuevo saldo pendiente'**
  String get runningBalanceLabel;

  /// DRV-6: services-per-period screen app bar title, and the nav button tooltip
  ///
  /// In es, this message translates to:
  /// **'Servicios por período'**
  String get servicesPeriodTitle;

  /// DRV-6: shown when there are no completed jobs yet
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes servicios completados.'**
  String get servicesPeriodEmptyBody;

  /// DRV-6: shown when loading services-per-period fails
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus servicios. Intenta de nuevo.'**
  String get servicesPeriodLoadError;

  /// DRV-6: count of completed jobs for a given day
  ///
  /// In es, this message translates to:
  /// **'{count} servicios'**
  String servicesCountLabel(int count);

  /// DRV-6: total cash fare collected for a given day
  ///
  /// In es, this message translates to:
  /// **'Efectivo cobrado'**
  String get servicesEarningsLabel;

  /// DRV-6: total commission owed for a given day
  ///
  /// In es, this message translates to:
  /// **'Comisión'**
  String get servicesCommissionLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
