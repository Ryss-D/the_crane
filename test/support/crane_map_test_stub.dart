import 'package:flutter/material.dart';
import 'package:the_crane/core/models/lat_lng.dart';
import 'package:the_crane/features/shared/widgets/crane_map.dart';

/// Installs [CraneMap.debugTestBuilder] so widget tests never construct the
/// real native Google Maps platform view (`MissingPluginException` under
/// `flutter_test` — see the doc comment on `debugTestBuilder` itself).
/// Called once from `flutter_test_config.dart`, for every test.
void installCraneMapTestStub() {
  CraneMap.debugTestBuilder = (map) => _CraneMapStub(map: map);
}

/// The position a test "tap" on the stub map reports — fixed and exported
/// so a test can assert the exact coordinate a real `CraneMap.onTap`
/// consumer received.
const craneMapStubTapPosition = LatLng(lat: 6.3, lng: -75.6);

/// Same as [craneMapStubTapPosition], for a simulated marker "drag".
const craneMapStubDragPosition = LatLng(lat: 6.31, lng: -75.61);

/// Renders each marker's role/id and whether a route was given as plain,
/// individually-keyed `Text` widgets instead of a real map — enough for a
/// test to assert "the pickup pin is showing" (`find.byKey(const
/// Key('craneMapMarker_pickup'))`) without needing real map tiles. A tap
/// anywhere on the map (when `onTap` is wired) reports
/// [craneMapStubTapPosition]; a tap on a draggable marker's own key
/// (`craneMapMarkerDrag_<id>`) simulates dragging it to
/// [craneMapStubDragPosition] — real gesture-drag simulation isn't
/// meaningful without real map tiles to drag across.
class _CraneMapStub extends StatelessWidget {
  const _CraneMapStub({required this.map});

  final CraneMap map;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.map_outlined),
        for (final marker in map.markers)
          GestureDetector(
            key: marker.onDragEnd == null ? null : Key('craneMapMarkerDrag_${marker.id}'),
            onTap: marker.onDragEnd == null
                ? null
                : () => marker.onDragEnd!(craneMapStubDragPosition),
            child: Text(
              '${marker.role.name}: ${marker.position.lat}, ${marker.position.lng}',
              key: Key('craneMapMarker_${marker.id}'),
            ),
          ),
        if ((map.routePoints?.length ?? 0) > 1)
          const Text('route', key: Key('craneMapRoute')),
      ],
    );

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: map.onTap == null
          ? content
          : GestureDetector(
              key: const Key('craneMapTapArea'),
              behavior: HitTestBehavior.translucent,
              onTap: () => map.onTap!(craneMapStubTapPosition),
              child: content,
            ),
    );
  }
}
