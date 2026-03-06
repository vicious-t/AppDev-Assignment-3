import 'package:image_picker/image_picker.dart';

import 'media_permission_service.dart';

class NoteImagePickerResult {
  final XFile? file;
  final bool permanentlyDenied;
  final String? error;

  const NoteImagePickerResult({
    required this.file,
    required this.permanentlyDenied,
    required this.error,
  });

  bool get ok => file != null && error == null;
}

class NoteImagePickerService {
  NoteImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<NoteImagePickerResult> pickFromGallery() async {
    final granted = await MediaPermissionService.requestGallery();

    if (!granted) {
      final permDenied =
      await MediaPermissionService.isGalleryPermanentlyDenied();

      return NoteImagePickerResult(
        file: null,
        permanentlyDenied: permDenied,
        error: permDenied
            ? 'Tilgang til bilder er blokkert. Gi tilgang i Innstillinger.'
            : 'Gi tilgang til bilder for å velge fra galleri.',
      );
    }

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      return NoteImagePickerResult(
        file: file,
        permanentlyDenied: false,
        error: null,
      );
    } catch (_) {
      return const NoteImagePickerResult(
        file: null,
        permanentlyDenied: false,
        error: 'Kunne ikke åpne galleri.',
      );
    }
  }

  Future<NoteImagePickerResult> pickFromCamera() async {
    final granted = await MediaPermissionService.requestCamera();

    if (!granted) {
      final permDenied =
      await MediaPermissionService.isCameraPermanentlyDenied();

      return NoteImagePickerResult(
        file: null,
        permanentlyDenied: permDenied,
        error: permDenied
            ? 'Kameratilgang er blokkert. Gi tilgang i Innstillinger.'
            : 'Gi kameratilgang for å ta bilde.',
      );
    }

    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      return NoteImagePickerResult(
        file: file,
        permanentlyDenied: false,
        error: null,
      );
    } catch (_) {
      return const NoteImagePickerResult(
        file: null,
        permanentlyDenied: false,
        error: 'Kunne ikke åpne kamera.',
      );
    }
  }
}