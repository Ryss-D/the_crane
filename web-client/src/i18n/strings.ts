import type { JobStatus, VehicleType } from '../api/types';

/**
 * es-CO strings, centralized so a real i18n layer (or at least en fallback)
 * can slot in later without hunting through components.
 */
export const strings = {
  appName: 'The Crane',
  tagline: 'Pide tu grúa en Medellín',

  auth: {
    title: 'Ingresa con tu celular',
    phoneLabel: 'Número de celular',
    phonePlaceholder: '300 123 4567',
    submit: 'Enviar código',
    devNote: 'Modo desarrollo: cualquier número y código funcionan.',
    signOut: 'Cerrar sesión',
    codeTitle: 'Ingresa el código',
    codeLabel: 'Código de verificación',
    codePlaceholder: '123456',
    codeSentTo: (phone: string) => `Enviamos un código a ${phone}`,
    confirm: 'Confirmar',
    changeNumber: 'Cambiar número',
    sendError: 'No pudimos enviar el código. Verifica el número e intenta de nuevo.',
    confirmError: 'Código incorrecto. Intenta de nuevo.',
  },

  request: {
    title: '¿Dónde está tu vehículo?',
    pickupLabel: 'Punto de recogida',
    pickupPlaceholder: 'Ej: Cra. 43A #1-50, El Poblado',
    dropoffLabel: '¿A dónde lo llevamos?',
    dropoffPlaceholder: 'Ej: Taller — Cl. 10 #52-25, Guayabal',
    mapPlaceholder: 'Mapa próximamente',
    vehicleTypeLabel: 'Tipo de vehículo',
    getQuote: 'Cotizar',
    quoting: 'Cotizando…',
    quoteTitle: 'Tu cotización',
    etaLabel: 'Llegada estimada',
    etaValue: (min: number) => `${min} min`,
    distanceLabel: 'Distancia',
    distanceValue: (km: number) => `${km.toLocaleString('es-CO')} km`,
    confirm: 'Confirmar grúa',
    confirming: 'Solicitando…',
    activeJobBanner: 'Tienes un servicio activo',
    activeJobLink: 'Ver seguimiento',
    error: 'No pudimos cotizar tu servicio. Intenta de nuevo.',
    createError: 'No pudimos crear tu solicitud. Intenta de nuevo.',
  },

  tracking: {
    title: 'Seguimiento de tu grúa',
    publicTitle: 'Seguimiento de grúa',
    timelineTitle: 'Estado del servicio',
    driverTitle: 'Tu conductor',
    plateLabel: 'Placa',
    shareLabel: 'Compartir seguimiento',
    shareCopied: 'Enlace copiado',
    loading: 'Cargando servicio…',
    notFound: 'No encontramos este servicio.',
    priceLabel: 'Total',
    etaLabel: 'ETA',
    publicNote: 'Vista pública de solo lectura — sin iniciar sesión.',
    pollNote: 'Se actualiza automáticamente cada 10 segundos.',
  },

  rating: {
    title: 'Califica tu servicio',
    submit: 'Enviar calificación',
    thanks: '¡Gracias por tu calificación!',
  },

  vehicleTypes: {
    moto: 'Moto',
    car: 'Carro',
    suv: 'Camioneta',
  } satisfies Record<VehicleType, string>,

  statuses: {
    requested: 'Solicitud recibida',
    matching: 'Buscando conductor',
    assigned: 'Conductor asignado',
    en_route_pickup: 'Grúa en camino',
    arrived_pickup: 'Grúa en el punto',
    loading: 'Cargando tu vehículo',
    in_transit: 'En camino al destino',
    delivered: 'Vehículo entregado',
    completed: 'Servicio completado',
    cancelled: 'Servicio cancelado',
    no_drivers: 'Sin conductores disponibles',
  } satisfies Record<JobStatus, string>,
} as const;
