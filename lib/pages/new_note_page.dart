import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/notes_provider.dart';
import '../services/note_image_picker_service.dart';
import '../services/media_permission_service.dart';
import '../services/note_image_service.dart';
import '../utils/supabase_error.dart';
import '../widgets/note_image_section.dart';

class NewNotePage extends ConsumerStatefulWidget {
  const NewNotePage({super.key});

  @override
  ConsumerState<NewNotePage> createState() => _NewNotePageState();
}

class _NewNotePageState extends ConsumerState<NewNotePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  final _picker = ImagePicker();
  final _imageService = NoteImageService();
  final _pickerService = NoteImagePickerService();

  XFile? _stagedImage;
  String? _imageError;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (_saving) return;

    final result = await _pickerService.pickFromCamera();

    if (!mounted) return;

    if (result.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Tilgang blokkert.'),
          action: SnackBarAction(
            label: 'Innstillinger',
            onPressed: () => MediaPermissionService.openAppSettingsPage(),
          ),
        ),
      );
      return;
    }

    if (result.file == null) {
      setState(() => _imageError = result.error);
      return;
    }

    setState(() {
      _stagedImage = result.file;
      _imageError = null;
    });
  }

  Future<void> _pickFromGallery() async {
    if (_saving) return;

    final result = await _pickerService.pickFromGallery();

    if (!mounted) return;

    if (result.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Tilgang blokkert.'),
          action: SnackBarAction(
            label: 'Innstillinger',
            onPressed: () => MediaPermissionService.openAppSettingsPage(),
          ),
        ),
      );
      return;
    }

    if (result.file == null) {
      setState(() => _imageError = result.error);
      return;
    }

    setState(() {
      _stagedImage = result.file;
      _imageError = null;
    });
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      String? imageUrl;

      if (_stagedImage != null) {
        await _imageService.validateOrThrow(_stagedImage!);
        imageUrl = await _imageService.uploadAndGetPublicUrl(_stagedImage!);
      }

      await ref.read(notesProvider.notifier).addNote(
        title: _titleController.text,
        content: _contentController.text,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notat lagret')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = supabaseErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Kunne ikke lagre notat' : msg)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nytt notat'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Lagre'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 +  MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ========= TITTEL =========
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tittel',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Tittel kan ikke være tom'
                    : null,
              ),
              const SizedBox(height: 12),

              // ========= INNHOLD =========
              TextFormField(
                controller: _contentController,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Innhold',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Innhold kan ikke være tomt'
                    : null,
              ),
              const SizedBox(height: 12),

              // ========= BILDE =========
              NoteImageSection(
                isOwner: true,
                saving: _saving,
                heroTagBase: 'new_note',
                stagedImage: _stagedImage,
                imageError: _imageError,
                onPickFromCamera: _pickFromCamera,
                onPickFromGallery: _pickFromGallery,
                onClearStagedImage: () => setState(() {
                  _stagedImage = null;
                  _imageError = null;
                }),
              ),

              const SizedBox(height: 12),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
                    : const Text('Lagre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}