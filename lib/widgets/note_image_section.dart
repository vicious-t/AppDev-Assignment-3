import 'dart:io';
import 'fullscreen_image_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class NoteImageSection extends StatelessWidget {
  const NoteImageSection({
    super.key,
    required this.isOwner,
    required this.saving,
    required this.stagedImage,
    required this.imageError,
    required this.onPickFromCamera,
    required this.onPickFromGallery,
    required this.onClearStagedImage,
    required this.heroTagBase,

    // Optional: eksisterende bilde + slett/angre
    this.imageUrl,
    this.removeExistingImage,
    this.onMarkRemoveExisting,
    this.onUndoRemoveExisting,
  });

  final bool isOwner;
  final bool saving;

  final XFile? stagedImage;
  final String? imageError;

  final VoidCallback onPickFromCamera;
  final VoidCallback onPickFromGallery;
  final VoidCallback onClearStagedImage;
  final String heroTagBase;

  final String? imageUrl;
  final bool? removeExistingImage;
  final VoidCallback? onMarkRemoveExisting;
  final VoidCallback? onUndoRemoveExisting;

  bool get _hasExistingImage =>
      imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get _supportsExistingControls =>
      _hasExistingImage &&
          removeExistingImage != null &&
          onMarkRemoveExisting != null &&
          onUndoRemoveExisting != null;

  @override
  Widget build(BuildContext context) {
    final canEdit = isOwner && !saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwner) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canEdit ? onPickFromCamera : null,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Ta bilde'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canEdit ? onPickFromGallery : null,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galleri'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Preview priority:
        // 1) staged image
        // 2) existing image (if supported + not marked removed)
        // 3) undo remove (if supported + marked removed)

        if (stagedImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  FullscreenImagePage.open(
                    context,
                    image: FileImage(File(stagedImage!.path)),
                    heroTag: '${heroTagBase}_staged',
                  );
                },
                child: Hero(
                  tag: '${heroTagBase}_staged',
                  child: Image.file(
                    File(stagedImage!.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isOwner)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: canEdit ? onClearStagedImage : null,
                icon: const Icon(Icons.close),
                label: const Text('Fjern nytt bilde'),
              ),
            ),
        ] else if (_supportsExistingControls &&
            removeExistingImage == false) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  FullscreenImagePage.open(
                    context,
                    image: NetworkImage(imageUrl!),
                    heroTag: '${heroTagBase}_existing',
                  );
                },
                child: Hero(
                  tag: '${heroTagBase}_existing',
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => const Center(
                      child: Text('Kunne ikke laste bilde'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isOwner)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: canEdit ? onMarkRemoveExisting : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Slett bilde'),
              ),
            ),
        ] else if (_supportsExistingControls &&
            removeExistingImage == true) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: canEdit ? onUndoRemoveExisting : null,
              icon: const Icon(Icons.undo),
              label: const Text('Angre sletting'),
            ),
          ),
        ] else if (_hasExistingImage) ...[
          // Read-only existing preview (if you ever use it in non-owner context)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes == null
                          ? null
                          : progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!,
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => const Center(
                  child: Text('Kunne ikke laste bilde'),
                ),
              ),
            ),
          ),
        ],

        if (imageError != null) ...[
          const SizedBox(height: 8),
          Text(
            imageError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}