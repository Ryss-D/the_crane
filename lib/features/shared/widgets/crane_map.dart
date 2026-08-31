import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../../core/models/lat_lng.dart';

/// Medellín city center — used as the default camera target wherever a real
/// position isn't known yet (mirrors `request_bloc.dart`'s `_medellin`).
const craneMapDefaultCenter = LatLng(lat: 6.2442, lng: -75.5812);

/// FND-6: a marker role, purely for a distinct color/label — this app has no
/// custom marker icon assets, so `BitmapDescriptor.defaultMarkerWithHue` is
/// the "reasonable substitute" for that (same call this app makes elsewhere
/// when a real asset isn't worth adding yet, e.g. DRV-6's bar-chart
/// substitute for a charting package).
enum CraneMapMarkerRole {
  pickup(hue: gmaps.BitmapDescriptor.hueGreen),
  dropoff(hue: gmaps.BitmapDescriptor.hueRed),
  self(hue: gmaps.BitmapDescriptor.hueAzure),
  driver(hue: gmaps.BitmapDescriptor.hueOrange);

  const CraneMapMarkerRole({required this.hue});

  final double hue;
}

/// One pin on a [CraneMap].
class CraneMapMarker {
  const CraneMapMarker({
    required this.id,
    required this.position,
    required this.role,
    this.label,
    this.onDragEnd,
  });

  final String id;
  final LatLng position;
  final CraneMapMarkerRole role;

  /// Shown in the marker's info window on tap — optional, purely cosmetic.
  final String? label;

  /// FND-6: when set, this marker is draggable and fires with its new
  /// position once the customer lets go (`RequestScreen`'s pickup/dropoff
  /// pins, once a search has placed one — see the CUS-1 doc note on why
  /// this only refines an already-placed pin rather than being the only
  /// way to place one). Null (the default) means a fixed, non-draggable
  /// pin — every other `CraneMap` use in the app.
  final ValueChanged<LatLng>? onDragEnd;
}

/// Thin wrapper over `google_maps_flutter`'s `GoogleMap`, replacing
/// `MapPlaceholder` across the app: fixed pickup/dropoff/driver markers plus
/// an optional route polyline. A marker with [CraneMapMarker.onDragEnd] set
/// is draggable; otherwise read-only (see `PlacesAutocompleteField` for the
/// request screen's interactive search).
///
/// Camera: centers on [markers]' centroid if any are given, else
/// [craneMapDefaultCenter]. Does not auto-fit zoom to bounds (a nice-to-have
/// left for later — [initialZoom] is a fixed, reasonable default for a
/// same-city pickup/dropoff pair).
class CraneMap extends StatelessWidget {
  const CraneMap({
    super.key,
    this.markers = const [],
    this.routePoints,
    this.onTap,
    this.initialZoom = 13,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final List<CraneMapMarker> markers;

  /// A polyline drawn through these points, in order — typically
  /// `DirectionsRepository.route`'s result. Null/empty draws no line.
  final List<LatLng>? routePoints;

  /// FND-6: tapping the map itself — `RequestScreen`'s way to place an
  /// *initial* pin with no prior search (closes the CUS-1 gap
  /// `CraneMapMarker.onDragEnd`-alone left: drag can only refine a pin that
  /// already exists). Null (the default) means a plain non-interactive map,
  /// every other `CraneMap` use in the app.
  final ValueChanged<LatLng>? onTap;

  final double initialZoom;
  final BorderRadius borderRadius;

  gmaps.LatLng get _center {
    if (markers.isEmpty) return craneMapDefaultCenter.toGoogleMaps();
    final lat = markers.map((m) => m.position.lat).reduce((a, b) => a + b) / markers.length;
    final lng = markers.map((m) => m.position.lng).reduce((a, b) => a + b) / markers.length;
    return gmaps.LatLng(lat, lng);
  }

  /// Test seam: `google_maps_flutter`'s `GoogleMap` creates a real native
  /// platform view, which throws `MissingPluginException` under
  /// `flutter_test` (there's no native host to answer it, and the package
  /// ships no first-party fake platform for widget tests to register
  /// instead). `test/flutter_test_config.dart` sets this once, for every
  /// test, to a lightweight stand-in (`test/support/crane_map_test_stub.dart`)
  /// that still exposes [markers]/[routePoints] as plain keyed `Text`
  /// widgets so a test can assert on them if it wants to. Production code
  /// never touches this — it stays null outside of `flutter_test`.
  @visibleForTesting
  static Widget Function(CraneMap map)? debugTestBuilder;

  @override
  Widget build(BuildContext context) {
    final testBuilder = debugTestBuilder;
    if (testBuilder != null) return testBuilder(this);
    return ClipRRect(
      borderRadius: borderRadius,
      child: gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(target: _center, zoom: initialZoom),
        markers: {
          for (final marker in markers)
            gmaps.Marker(
              markerId: gmaps.MarkerId(marker.id),
              position: marker.position.toGoogleMaps(),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(marker.role.hue),
              infoWindow: marker.label == null
                  ? gmaps.InfoWindow.noText
                  : gmaps.InfoWindow(title: marker.label),
              draggable: marker.onDragEnd != null,
              onDragEnd: marker.onDragEnd == null
                  ? null
                  : (position) => marker.onDragEnd!(position.toAppLatLng()),
            ),
        },
        polylines: {
          if (routePoints != null && routePoints!.length > 1)
            gmaps.Polyline(
              polylineId: const gmaps.PolylineId('route'),
              points: routePoints!.map((p) => p.toGoogleMaps()).toList(growable: false),
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
        },
        onTap: onTap == null ? null : (position) => onTap!(position.toAppLatLng()),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }
}
