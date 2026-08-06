// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'The Crane';

  @override
  String get signInTitle => 'Inicia sesión';

  @override
  String get signInSubtitle =>
      'Pide una grúa para tu moto o carro en Medellín.';

  @override
  String get signInPhoneLabel => 'Número de celular';

  @override
  String get signInPhoneHint => '300 123 4567';

  @override
  String get signInPhoneButton => 'Enviar código';

  @override
  String get signInSendCodeError =>
      'No pudimos enviar el código. Verifica el número e intenta de nuevo.';

  @override
  String get otpTitle => 'Ingresa el código';

  @override
  String otpSentTo(String phone) {
    return 'Enviamos un código a $phone';
  }

  @override
  String get otpLabel => 'Código de verificación';

  @override
  String get otpHint => '123456';

  @override
  String get otpConfirmButton => 'Confirmar';

  @override
  String get otpChangeNumber => 'Cambiar número';

  @override
  String get otpConfirmError => 'Código incorrecto. Intenta de nuevo.';

  @override
  String get completeProfileTitle => '¿Cómo te llamas?';

  @override
  String get completeProfileSubtitle =>
      'Lo usamos para que tu conductor o cliente sepa quién eres.';

  @override
  String get completeProfileNameLabel => 'Nombre completo';

  @override
  String get completeProfileSaveButton => 'Continuar';

  @override
  String get customerHomeTitle => 'Pedir grúa';

  @override
  String get driverHomeTitle => 'Panel del conductor';

  @override
  String get mapPlaceholderBody => 'Aquí irá el mapa de Google Maps.';

  @override
  String get pickupFieldLabel => 'Punto de recogida';

  @override
  String get pickupFieldHint => '¿Dónde está tu vehículo?';

  @override
  String get dropoffFieldLabel => 'Destino';

  @override
  String get dropoffFieldHint => '¿A dónde lo llevamos?';

  @override
  String get vehicleTypeLabel => 'Tipo de vehículo';

  @override
  String get vehicleMoto => 'Moto';

  @override
  String get vehicleCar => 'Carro';

  @override
  String get vehicleSuv => 'SUV';

  @override
  String get quotePrompt => 'Ingresa la recogida y el destino para cotizar.';

  @override
  String get quoteError => 'No pudimos calcular la tarifa. Intenta de nuevo.';

  @override
  String quoteEtaMinutes(int minutes) {
    return 'Llega en $minutes min';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get confirmRequestButton => 'Confirmar solicitud';

  @override
  String get matchingTitle => 'Buscando tu grúa';

  @override
  String get matchingBody => 'Estamos contactando a los conductores cercanos…';

  @override
  String get assignedTitle => '¡Grúa asignada!';

  @override
  String get assignedBody => 'Tu conductor va en camino al punto de recogida.';

  @override
  String driverPlateLabel(String plate) {
    return 'Placa $plate';
  }

  @override
  String get noDriversTitle => 'Sin grúas disponibles';

  @override
  String get noDriversBody =>
      'Por ahora no hay conductores disponibles. Intenta de nuevo.';

  @override
  String get retryButton => 'Reintentar';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get backToHomeButton => 'Volver al inicio';

  @override
  String get truckTypeMotoOnly => 'Grúa de motos';

  @override
  String get truckTypeCar => 'Grúa de carros';

  @override
  String get truckTypeFlatbed => 'Planchón';

  @override
  String get availabilityOffline => 'Desconectado';

  @override
  String get availabilityAvailable => 'Disponible';

  @override
  String get availabilityOnJob => 'En servicio';

  @override
  String get goAvailableButton => 'Conectarme';

  @override
  String get goOfflineButton => 'Desconectarme';

  @override
  String get offlineHint => 'Conéctate para recibir ofertas de servicio.';

  @override
  String get availableHint => 'Esperando ofertas cercanas…';

  @override
  String get blockedBannerUnverified =>
      'Tu cuenta está pendiente de verificación. No recibirás ofertas todavía.';

  @override
  String get devTriggerOfferButton => 'Simular oferta (dev)';

  @override
  String get offerTitle => 'Nueva oferta de servicio';

  @override
  String offerPickupDistance(String km) {
    return 'A $km km de ti';
  }

  @override
  String get fareLabel => 'Tarifa';

  @override
  String get offerCommissionLabel => 'Comisión plataforma';

  @override
  String get offerEarningsLabel => 'Tu ganancia';

  @override
  String offerCountdown(int seconds) {
    return 'Expira en $seconds s';
  }

  @override
  String get acceptButton => 'Aceptar';

  @override
  String get rejectButton => 'Rechazar';

  @override
  String get activeJobTitle => 'Servicio activo';

  @override
  String get statusRequested => 'Solicitada';

  @override
  String get statusMatching => 'Buscando conductor';

  @override
  String get statusAssigned => 'Asignada';

  @override
  String get statusEnRoutePickup => 'En camino a la recogida';

  @override
  String get statusArrivedPickup => 'En el punto de recogida';

  @override
  String get statusLoading => 'Cargando el vehículo';

  @override
  String get statusInTransit => 'En ruta al destino';

  @override
  String get statusDelivered => 'Entregada';

  @override
  String get statusCompleted => 'Completada';

  @override
  String get statusCancelled => 'Cancelada';

  @override
  String get statusNoDrivers => 'Sin conductores';

  @override
  String get advanceEnRoutePickup => 'En camino';

  @override
  String get advanceArrivedPickup => 'Llegué';

  @override
  String get advanceLoading => 'Cargando vehículo';

  @override
  String get advanceInTransit => 'En ruta';

  @override
  String get advanceDelivered => 'Entregado';

  @override
  String get advanceCompleted => 'Finalizar servicio';

  @override
  String get jobDoneBody => 'Servicio finalizado. ¡Buen trabajo!';

  @override
  String get rateTripButton => 'Calificar viaje';

  @override
  String get rateDialogTitle => '¿Cómo estuvo tu viaje?';

  @override
  String get rateCommentHint => 'Comentario (opcional)';

  @override
  String get submitRatingButton => 'Enviar calificación';

  @override
  String get skipRatingButton => 'Omitir';

  @override
  String get rateSubmitError =>
      'No pudimos enviar tu calificación. Intenta de nuevo.';

  @override
  String get historyTitle => 'Historial de viajes';

  @override
  String get historyEmptyBody => 'Aún no tienes viajes.';

  @override
  String get historyLoadError =>
      'No pudimos cargar tu historial. Intenta de nuevo.';

  @override
  String get historyLoadMoreButton => 'Cargar más';

  @override
  String get historyDetailTitle => 'Detalle del viaje';

  @override
  String get ratingsSectionTitle => 'Calificaciones';

  @override
  String get noRatingsBody => 'Sin calificaciones todavía.';

  @override
  String get ratingFromCustomerLabel => 'Calificación al conductor';

  @override
  String get ratingFromDriverLabel => 'Calificación al cliente';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get becomeDriverMenuItem => 'Convertirme en conductor';

  @override
  String get becomeDriverTitle => 'Conviértete en conductor';

  @override
  String get becomeDriverIntro =>
      'Registra tu grúa para empezar a recibir servicios.';

  @override
  String get plateFieldLabel => 'Placa';

  @override
  String get plateFieldHint => 'ABC123';

  @override
  String get truckTypeFieldLabel => 'Tipo de grúa';

  @override
  String get capacityFieldLabel => 'Capacidad de la grúa';

  @override
  String get capacityMoto => 'Motos';

  @override
  String get capacityCar => 'Carros';

  @override
  String get capacityBoth => 'Motos y carros';

  @override
  String get licenseUrlFieldLabel => 'URL de la licencia (opcional)';

  @override
  String get truckPhotoUrlFieldLabel => 'URL de foto de la grúa (opcional)';

  @override
  String get becomeDriverSubmitButton => 'Enviar registro';

  @override
  String get becomeDriverSubmitError =>
      'No pudimos completar el registro. Intenta de nuevo.';

  @override
  String get cashPaymentPendingBody =>
      'Confirma que recibiste el pago en efectivo para finalizar el servicio.';

  @override
  String get cashConfirmButton => 'Pagado en efectivo';

  @override
  String get cashPaymentConfirmError =>
      'No pudimos confirmar el pago. Intenta de nuevo.';

  @override
  String get waitingCashConfirmationBody =>
      'Esperando que el cliente confirme el pago en efectivo.';
}
