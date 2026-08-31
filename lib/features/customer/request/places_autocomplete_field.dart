import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/places_repository.dart';
import '../../../core/models/place_prediction.dart';

/// FND-6 — an address field backed by real Places autocomplete. Manually
/// typed text is still always accepted as-is (via [onTextChanged], the same
/// event `RequestBloc` already had before this) so `fakeGeocode` keeps
/// working as the last-resort fallback for whatever the customer types but
/// never picks a suggestion for — mirrors the web client's identical
/// "GPS/Places coords win when we have them, typed text falls back to
/// fakeGeocode otherwise" approach (`web-client/src/features/request/RequestPage.tsx`).
///
/// No debounce: each keystroke re-queries (guarded by a request token so a
/// slow/out-of-order response can't clobber a newer one). Simpler and safer
/// than a `Timer`-based debounce, which risks leaving a pending timer behind
/// in a widget test that doesn't pump long enough to let it fire — a real
/// concern given how many existing tests type into this exact field and
/// move on immediately. A production nicety to revisit, not a correctness
/// issue: worst case is one extra request per keystroke against the
/// backend's Places proxy.
class PlacesAutocompleteField extends StatefulWidget {
  const PlacesAutocompleteField({
    super.key,
    required this.fieldKey,
    required this.text,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    required this.textInputAction,
    required this.onTextChanged,
    required this.onPlaceSelected,
  });

  final Key fieldKey;

  /// The current address text — a controlled field. Needed so an external
  /// change (a map tap/pin-drag setting `RequestState.pickupAddress`
  /// directly, bypassing this field entirely) is reflected here too, not
  /// just typing/selecting within the field itself.
  final String text;

  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final TextInputAction textInputAction;

  /// Fired on every keystroke, same as the plain `TextField` this replaces.
  final ValueChanged<String> onTextChanged;

  /// Fired once a suggestion resolves to real coordinates.
  final ValueChanged<PlaceDetails> onPlaceSelected;

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  late final _controller = TextEditingController(text: widget.text);
  int _requestToken = 0;
  List<PlacePrediction> _predictions = const [];

  @override
  void didUpdateWidget(covariant PlacesAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from an *external* change — if `_controller.text` already
    // matches, this update came from this field's own typing/selection
    // (which already set the controller directly) and touching it again
    // would just reset the cursor position mid-type for no reason.
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onTextChanged(value);
    unawaited(_search(value));
  }

  Future<void> _search(String value) async {
    final token = ++_requestToken;
    if (value.trim().length < 3) {
      setState(() => _predictions = const []);
      return;
    }
    List<PlacePrediction> results;
    try {
      results = await context.read<PlacesRepository>().autocomplete(value);
    } catch (_) {
      results = const [];
    }
    if (!mounted || token != _requestToken) return;
    setState(() => _predictions = results);
  }

  Future<void> _select(PlacePrediction prediction) async {
    setState(() => _predictions = const []);
    _controller.value = TextEditingValue(
      text: prediction.description,
      selection: TextSelection.collapsed(offset: prediction.description.length),
    );
    widget.onTextChanged(prediction.description);
    try {
      final details = await context.read<PlacesRepository>().placeDetails(prediction.placeId);
      if (!mounted) return;
      widget.onPlaceSelected(details);
    } catch (_) {
      // Best-effort: the selected text still stands as a manually-typed
      // address would (fakeGeocode picks it up), just without real
      // coordinates this time.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: widget.fieldKey,
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: widget.textInputAction,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: Icon(widget.prefixIcon),
            border: const OutlineInputBorder(),
          ),
        ),
        if (_predictions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final prediction in _predictions)
                  ListTile(
                    key: Key('placePrediction_${prediction.placeId}'),
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(prediction.description),
                    onTap: () => _select(prediction),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
