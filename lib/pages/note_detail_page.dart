import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/note_image_picker_service.dart';
import '../services/media_permission_service.dart';
import '../services/note_image_service.dart';
import '../utils/supabase_error.dart';
import '../widgets/note_image_section.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  final Note note;

  const NoteDetailPage({super.key, required this.note});

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  final _picker = ImagePicker();
  final _imageService = NoteImageService();
  final _pickerService = NoteImagePickerService();

  XFile? _stagedImage;
  bool _removeExistingImage = false;
  String? _imageError;

  bool _saving = false;

  bool get isOwner {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid != null && uid == widget.note.userId;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // =====================
  // Image picking
  // =====================

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

  // =====================
  // Unsaved changes
  // =====================

  bool _hasUnsavedChanges(Note note) {
    final textChanged =
        _titleController.text != note.title ||
            _contentController.text != note.content;

    final imageChanged = _stagedImage != null || _removeExistingImage;

    return textChanged || imageChanged;
  }

  // =====================
  // Save / Delete
  // =====================

  Future<void> _save() async {
    if (!isOwner) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final oldUrl = widget.note.imageUrl;
    String? newUrl;

    try {
      // 1) Hvis nytt staged bilde → valider + upload først
      if (_stagedImage != null) {
        await _imageService.validateOrThrow(_stagedImage!);
        newUrl = await _imageService.uploadAndGetPublicUrl(_stagedImage!);
      }

      // 2) Bestem bilde-handling i DB
      final shouldClearImage = _removeExistingImage && newUrl == null;

      // 3) Oppdater DB (title/content + ev bilde)
      await ref.read(notesProvider.notifier).updateNote(
        id: widget.note.id,
        title: _titleController.text,
        content: _contentController.text,
        imageUrl: newUrl,
        clearImage: shouldClearImage,
      );

      // 4) Storage cleanup (etter DB er oppdatert)
      // 4a) Hvis vi byttet bilde → slett gammel fil
      final replaced = newUrl != null && oldUrl != null && oldUrl.isNotEmpty;
      if (replaced) {
        await _imageService.deleteByPublicUrl(oldUrl!);
      }

      // 4b) Hvis vi slettet bilde uten å erstatte → slett gammel fil
      final cleared = shouldClearImage && oldUrl != null && oldUrl.isNotEmpty;
      if (cleared) {
        await _imageService.deleteByPublicUrl(oldUrl!);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endringer lagret')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = supabaseErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Kunne ikke lagre endringer' : msg)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNote() async {
    if (!isOwner || _saving) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slett notat?'),
        content: const Text('Dette kan ikke angres.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Slett'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(notesProvider.notifier).deleteNote(widget.note.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notat slettet')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = supabaseErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Kunne ikke slette notat' : msg)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =====================
  // UI
  // =====================

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return WillPopScope(
      onWillPop: () async {
        if (!_hasUnsavedChanges(note)) return true;

        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ulagrede endringer'),
            content: const Text('Vil du forkaste endringene?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Forkast'),
              ),
            ],
          ),
        );

        return shouldLeave ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notat'),
          actions: [
            if (isOwner) ...[
              IconButton(
                onPressed: _saving ? null : _deleteNote,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Slett',
              ),
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
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ========= TITTEL =========
                TextFormField(
                  controller: _titleController,
                  readOnly: !isOwner,
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
                  readOnly: !isOwner,
                  minLines: 10,
                  maxLines: 18,
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
                  isOwner: isOwner,
                  saving: _saving,
                  stagedImage: _stagedImage,
                  imageError: _imageError,
                  heroTagBase: 'note_${note.id}',
                  onPickFromCamera: _pickFromCamera,
                  onPickFromGallery: _pickFromGallery,
                  onClearStagedImage: () => setState(() {
                    _stagedImage = null;
                    _imageError = null;
                  }),
                  imageUrl: note.imageUrl,
                  removeExistingImage: _removeExistingImage,
                  onMarkRemoveExisting: () => setState(() {
                    _removeExistingImage = true;
                    _imageError = null;
                  }),
                  onUndoRemoveExisting: () => setState(() {
                    _removeExistingImage = false;
                    _imageError = null;
                  }),
                ),

                if (isOwner) ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}