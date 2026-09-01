import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/models/truck.dart';
import '../../../core/storage/document_image_picker.dart';
import '../../../core/storage/document_upload_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_cubit.dart';
import '../../shared/labels.dart';

/// AUTH-5 — a signed-in customer becomes a driver: truck plate/type/
/// capacity, plus optional license/truck-photo documents.
///
/// AUTH-5 follow-up (2026-08-31): document upload is now real. The driver
/// picks an image via [DocumentImagePicker] (`image_picker`'s gallery
/// chooser) and it uploads immediately to Firebase Storage via
/// [DocumentUploadRepository], rather than waiting for form submit --
/// visible per-document progress/failure state this way, and submit itself
/// doesn't have to also juggle in-flight uploads. The resulting download URL
/// is what actually gets sent as `licenseUrl`/`truckPhotoUrl` to
/// `registerDriver`, same shape the backend has always expected (plain
/// opaque strings — see `DriverRegisterRequest` in
/// `backend/app/schemas/driver.py`). Both documents stay optional: a picked
/// document whose upload fails is simply left out of the request rather than
/// blocking registration -- the driver can retry the pick, or just submit
/// without it and add it later.
///
/// FLT-4 adds a second, mutually exclusive path: redeeming a fleet owner's
/// invite instead of registering your own truck. The real product shape for
/// this would be a deep link carrying the invite token (tap a link the
/// fleet owner sent over WhatsApp/SMS, land here pre-filled); this app has
/// no deep-link handling wired yet (go_router's own URL routing only covers
/// in-app navigation), so as a pragmatic stand-in this screen instead lets
/// the driver paste/type the invite token by hand. Swap this field for a
/// deep-link-populated one once that plumbing exists.
///
/// On success the backend has already flipped the caller's role to
/// `driver` server-side; [AuthCubit.refreshUser] re-syncs the local profile
/// so `routerRedirect` (`lib/app/router.dart`) lands on the driver shell on
/// its next redirect evaluation — no explicit navigation is done here.
class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

/// Which shape of `registerDriver` this screen is currently filling out.
enum _RegistrationMode { ownTruck, invite }

/// Which of the two optional documents a [_DocumentUploadState] is for --
/// only used to pick the storage `kind` and the l10n copy, kept separate
/// from any driver-domain enum since this is purely a screen-local concern.
enum _DocumentKind { license, truckPhoto }

/// Per-document pick/upload progress, one instance each for the license and
/// truck-photo pickers.
enum _UploadStatus { none, uploading, uploaded, failed }

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  final _plateController = TextEditingController();
  final _inviteTokenController = TextEditingController();
  TruckType _truckType = TruckType.flatbed;
  TruckCapacity _capacity = TruckCapacity.both;
  _RegistrationMode _mode = _RegistrationMode.ownTruck;
  bool _submitting = false;
  bool _failed = false;

  File? _licenseFile;
  String? _licenseUrl;
  _UploadStatus _licenseStatus = _UploadStatus.none;

  File? _truckPhotoFile;
  String? _truckPhotoUrl;
  _UploadStatus _truckPhotoStatus = _UploadStatus.none;

  @override
  void dispose() {
    _plateController.dispose();
    _inviteTokenController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _licenseStatus != _UploadStatus.uploading &&
      _truckPhotoStatus != _UploadStatus.uploading &&
      (_mode == _RegistrationMode.invite
          ? _inviteTokenController.text.trim().isNotEmpty
          : _plateController.text.trim().isNotEmpty);

  Future<void> _pickAndUpload(_DocumentKind kind) async {
    final picker = context.read<DocumentImagePicker>();
    File? picked;
    try {
      picked = await picker.pickImage();
    } catch (_) {
      if (!mounted) return;
      setState(() => _setStatus(kind, _UploadStatus.failed));
      return;
    }
    final file = picked;
    if (file == null) return; // user backed out of the chooser
    if (!mounted) return;
    setState(() {
      _setFile(kind, file);
      _setStatus(kind, _UploadStatus.uploading);
    });
    try {
      final userId = context.read<AuthCubit>().state.user?.id ?? 'unknown';
      final url = await context.read<DocumentUploadRepository>().uploadDriverDocument(
            driverUserId: userId,
            kind: kind == _DocumentKind.license ? 'license' : 'truck_photo',
            file: file,
          );
      if (!mounted) return;
      setState(() {
        _setUrl(kind, url);
        _setStatus(kind, _UploadStatus.uploaded);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _setStatus(kind, _UploadStatus.failed));
    }
  }

  void _setFile(_DocumentKind kind, File file) {
    switch (kind) {
      case _DocumentKind.license:
        _licenseFile = file;
      case _DocumentKind.truckPhoto:
        _truckPhotoFile = file;
    }
  }

  void _setUrl(_DocumentKind kind, String url) {
    switch (kind) {
      case _DocumentKind.license:
        _licenseUrl = url;
      case _DocumentKind.truckPhoto:
        _truckPhotoUrl = url;
    }
  }

  void _setStatus(_DocumentKind kind, _UploadStatus status) {
    switch (kind) {
      case _DocumentKind.license:
        _licenseStatus = status;
      case _DocumentKind.truckPhoto:
        _truckPhotoStatus = status;
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      await context.read<DriversRepository>().registerDriver(
            plate: _mode == _RegistrationMode.ownTruck
                ? _plateController.text.trim()
                : null,
            truckType: _mode == _RegistrationMode.ownTruck ? _truckType : null,
            capacity: _mode == _RegistrationMode.ownTruck ? _capacity : null,
            inviteToken: _mode == _RegistrationMode.invite
                ? _inviteTokenController.text.trim()
                : null,
            licenseUrl: _licenseUrl,
            truckPhotoUrl: _truckPhotoUrl,
          );
      if (!mounted) return;
      await context.read<AuthCubit>().refreshUser();
      // routerRedirect now sees role == driver and sends us to the driver
      // shell; nothing else to do here.
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.becomeDriverTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.becomeDriverIntro),
              const SizedBox(height: 24),
              SegmentedButton<_RegistrationMode>(
                key: const Key('registrationModeSelector'),
                segments: [
                  ButtonSegment(
                    value: _RegistrationMode.ownTruck,
                    label: Text(l10n.becomeDriverModeOwnTruck),
                  ),
                  ButtonSegment(
                    value: _RegistrationMode.invite,
                    label: Text(l10n.becomeDriverModeInvite),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 16),
              if (_mode == _RegistrationMode.invite) ...[
                Text(l10n.becomeDriverInviteIntro),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('inviteTokenField'),
                  controller: _inviteTokenController,
                  decoration: InputDecoration(
                    labelText: l10n.inviteTokenFieldLabel,
                    hintText: l10n.inviteTokenFieldHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                TextField(
                  key: const Key('plateField'),
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.plateFieldLabel,
                    hintText: l10n.plateFieldHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(l10n.truckTypeFieldLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<TruckType>(
                  key: const Key('truckTypeSelector'),
                  segments: [
                    for (final type in TruckType.values)
                      ButtonSegment(value: type, label: Text(type.label(l10n))),
                  ],
                  selected: {_truckType},
                  onSelectionChanged: (selection) =>
                      setState(() => _truckType = selection.first),
                ),
                const SizedBox(height: 16),
                Text(l10n.capacityFieldLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<TruckCapacity>(
                  key: const Key('capacitySelector'),
                  segments: [
                    for (final capacity in TruckCapacity.values)
                      ButtonSegment(
                        value: capacity,
                        label: Text(capacity.label(l10n)),
                      ),
                  ],
                  selected: {_capacity},
                  onSelectionChanged: (selection) =>
                      setState(() => _capacity = selection.first),
                ),
              ],
              const SizedBox(height: 16),
              _DocumentPicker(
                keyPrefix: 'license',
                label: l10n.licenseDocumentLabel,
                file: _licenseFile,
                status: _licenseStatus,
                onPick: () => _pickAndUpload(_DocumentKind.license),
              ),
              const SizedBox(height: 12),
              _DocumentPicker(
                keyPrefix: 'truckPhoto',
                label: l10n.truckPhotoDocumentLabel,
                file: _truckPhotoFile,
                status: _truckPhotoStatus,
                onPick: () => _pickAndUpload(_DocumentKind.truckPhoto),
              ),
              if (_failed) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.becomeDriverSubmitError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('becomeDriverSubmitButton'),
                onPressed: _canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.becomeDriverSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One document's pick-button + thumbnail + upload-status row. Stateless --
/// all the actual state lives on `_BecomeDriverScreenState`, this just
/// renders it and forwards taps.
class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.keyPrefix,
    required this.label,
    required this.file,
    required this.status,
    required this.onPick,
  });

  /// Prefixes this row's widget keys (`'license'`/`'truckPhoto'`) so tests
  /// can target either document independently.
  final String keyPrefix;
  final String label;
  final File? file;
  final _UploadStatus status;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: file == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image_outlined, color: theme.colorScheme.outline),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        file!,
                        key: Key('${keyPrefix}Thumbnail'),
                        fit: BoxFit.cover,
                      ),
                      if (status == _UploadStatus.uploading)
                        Container(
                          color: Colors.black45,
                          alignment: Alignment.center,
                          child: const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              if (status == _UploadStatus.uploading)
                Text(l10n.documentUploading, style: theme.textTheme.bodySmall)
              else if (status == _UploadStatus.uploaded)
                Text(
                  l10n.documentUploaded,
                  key: Key('${keyPrefix}UploadedLabel'),
                  style: theme.textTheme.bodySmall,
                )
              else if (status == _UploadStatus.failed)
                Text(
                  l10n.documentUploadFailed,
                  key: Key('${keyPrefix}UploadError'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          key: Key('${keyPrefix}PickButton'),
          onPressed: status == _UploadStatus.uploading ? null : onPick,
          child: Text(file == null ? l10n.documentPickButton : l10n.documentReplaceButton),
        ),
      ],
    );
  }
}
