import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';
import '../models/note.dart';

class NotesRepository {
  NotesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Note>> fetchNotes() async {
    final data = await _client
        .from('notes')
        .select('id, user_id, title, content, updated_at, image_url, profiles(email)')
        .order('updated_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(data as List);
    return list.map(Note.fromMap).toList();
  }

  Future<void> addNote({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    final uid = _client.auth.currentUser!.id;

    await _client.from('notes').insert({
      'title': title.trim(),
      'content': content.trim(),
      'user_id': uid,
      'image_url': imageUrl,
    });
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    final updateData = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (clearImage) {
      updateData['image_url'] = null;
    } else if (imageUrl != null) {
      updateData['image_url'] = imageUrl;
    }

    try {
      final res = await _client
          .from('notes')
          .update(updateData)
          .eq('id', id)
          .select('id');

      final list = res as List;
      if (list.isEmpty) {
        throw Exception('Ingen tilgang til å oppdatere dette notatet.');
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> deleteNote({required String id}) async {
    try {
      final res = await _client.from('notes').delete().eq('id', id).select('id');

      final list = res as List;
      if (list.isEmpty) {
        throw Exception('Ingen tilgang til å slette dette notatet.');
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}