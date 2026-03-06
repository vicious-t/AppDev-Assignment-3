import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(Supabase.instance.client);
});

final notesProvider =
AsyncNotifierProvider<NotesController, List<Note>>(NotesController.new);

class NotesController extends AsyncNotifier<List<Note>> {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  RealtimeChannel? _channel;

  @override
  Future<List<Note>> build() async {
    // Starter realtime subscription once
    _channel ??= Supabase.instance.client
        .channel('notes_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notes',
      callback: (_) {
        refresh();
      },
    )
        .subscribe();

    ref.onDispose(() {
      if (_channel != null) {
        Supabase.instance.client.removeChannel(_channel!);
        _channel = null;
      }
    });

    return _repo.fetchNotes();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _repo.fetchNotes());
  }

  Future<void> addNote({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    await _repo.addNote(title: title, content: content, imageUrl: imageUrl);
    await refresh();
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    await _repo.updateNote(
      id: id,
      title: title,
      content: content,
      imageUrl: imageUrl,
      clearImage: clearImage,
    );
    await refresh();
  }

  Future<void> deleteNote(String id) async {
    await _repo.deleteNote(id: id);
    await refresh();
  }
}