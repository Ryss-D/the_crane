// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JobDriverSummary _$JobDriverSummaryFromJson(Map<String, dynamic> json) =>
    _JobDriverSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      truckPlate: json['truck_plate'] as String,
      truckType: $enumDecodeNullable(_$TruckTypeEnumMap, json['truck_type']),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      photoUrl: json['photo_url'] as String?,
    );

Map<String, dynamic> _$JobDriverSummaryToJson(_JobDriverSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'truck_plate': instance.truckPlate,
      'truck_type': _$TruckTypeEnumMap[instance.truckType],
      'rating_avg': instance.ratingAvg,
      'photo_url': instance.photoUrl,
    };

const _$TruckTypeEnumMap = {
  TruckType.motoOnly: 'moto_only',
  TruckType.car: 'car',
  TruckType.flatbed: 'flatbed',
};

_Job _$JobFromJson(Map<String, dynamic> json) => _Job(
  id: json['id'] as String,
  customerId: json['customer_id'] as String,
  driverId: json['driver_id'] as String?,
  status: $enumDecode(_$JobStatusEnumMap, json['status']),
  vehicleType: $enumDecode(_$VehicleTypeEnumMap, json['vehicle_type']),
  pickup: LatLng.fromJson(json['pickup'] as Map<String, dynamic>),
  pickupAddress: json['pickup_address'] as String,
  dropoff: LatLng.fromJson(json['dropoff'] as Map<String, dynamic>),
  dropoffAddress: json['dropoff_address'] as String,
  distanceKm: (json['distance_km'] as num).toDouble(),
  quotedPrice: (json['quoted_price'] as num).toInt(),
  finalPrice: (json['final_price'] as num?)?.toInt(),
  paymentMethod: json['payment_method'] as String? ?? 'cash',
  driver: json['driver'] == null
      ? null
      : JobDriverSummary.fromJson(json['driver'] as Map<String, dynamic>),
  requestedAt: DateTime.parse(json['requested_at'] as String),
  assignedAt: json['assigned_at'] == null
      ? null
      : DateTime.parse(json['assigned_at'] as String),
  pickedUpAt: json['picked_up_at'] == null
      ? null
      : DateTime.parse(json['picked_up_at'] as String),
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
  cancelledAt: json['cancelled_at'] == null
      ? null
      : DateTime.parse(json['cancelled_at'] as String),
  cancelReason: json['cancel_reason'] as String?,
  shareToken: json['share_token'] as String?,
  driverCommission: (json['driver_commission'] as num?)?.toInt(),
);

Map<String, dynamic> _$JobToJson(_Job instance) => <String, dynamic>{
  'id': instance.id,
  'customer_id': instance.customerId,
  'driver_id': instance.driverId,
  'status': _$JobStatusEnumMap[instance.status]!,
  'vehicle_type': _$VehicleTypeEnumMap[instance.vehicleType]!,
  'pickup': instance.pickup.toJson(),
  'pickup_address': instance.pickupAddress,
  'dropoff': instance.dropoff.toJson(),
  'dropoff_address': instance.dropoffAddress,
  'distance_km': instance.distanceKm,
  'quoted_price': instance.quotedPrice,
  'final_price': instance.finalPrice,
  'payment_method': instance.paymentMethod,
  'driver': instance.driver?.toJson(),
  'requested_at': instance.requestedAt.toIso8601String(),
  'assigned_at': instance.assignedAt?.toIso8601String(),
  'picked_up_at': instance.pickedUpAt?.toIso8601String(),
  'completed_at': instance.completedAt?.toIso8601String(),
  'cancelled_at': instance.cancelledAt?.toIso8601String(),
  'cancel_reason': instance.cancelReason,
  'share_token': instance.shareToken,
  'driver_commission': instance.driverCommission,
};

const _$JobStatusEnumMap = {
  JobStatus.requested: 'requested',
  JobStatus.matching: 'matching',
  JobStatus.assigned: 'assigned',
  JobStatus.enRoutePickup: 'en_route_pickup',
  JobStatus.arrivedPickup: 'arrived_pickup',
  JobStatus.loading: 'loading',
  JobStatus.inTransit: 'in_transit',
  JobStatus.delivered: 'delivered',
  JobStatus.completed: 'completed',
  JobStatus.cancelled: 'cancelled',
  JobStatus.noDrivers: 'no_drivers',
};

const _$VehicleTypeEnumMap = {
  VehicleType.moto: 'moto',
  VehicleType.car: 'car',
  VehicleType.suv: 'suv',
};
